import CoreServices
import CryptoKit
import DiffItProtocol
import Foundation

/// Keeps a changeset that came from `git difftool` in step with its repository. Whenever anything
/// under the repository root changes, the same comparison is run again (`git diff --raw` with the
/// arguments the CLI captured): files that joined it are added, with their base version extracted
/// into the app's cache; files that left it are removed; a file whose base changed (staged,
/// committed) is replaced. When the working tree is a side of the comparison, untracked files
/// count as added. git is only ever read from; the snapshots live under the app's cache.
@MainActor
final class RepoTracker {
    let root: String
    let arguments: [String]
    private weak var changeSet: ChangeSet?
    private let snapshotDirectory: URL
    private let watchRoot: String
    private var comparison: Comparison?
    private var stream: FSEventStreamRef?
    private var listener: EventListener?
    private var refreshing = false
    private var refreshPending = false
    private var debounce: Task<Void, Never>?

    /// Quiet time after a change before the comparison is run again.
    private static let settleDelay: Duration = .milliseconds(300)
    /// The CLI run that created the changeset is still arriving when tracking starts; the first
    /// refresh waits for it (or for `runCompleted`).
    private static let runDelay: Duration = .seconds(1)

    init(changeSet: ChangeSet, root: String, arguments: [String]) {
        self.changeSet = changeSet
        self.root = root
        self.arguments = arguments
        watchRoot = URL(fileURLWithPath: root).resolvingSymlinksInPath().path
        snapshotDirectory = DiffItPaths.snapshotsRoot().appendingPathComponent("track-" + UUID().uuidString)
        changeSet.snapshotDirectories.insert(snapshotDirectory.path)
    }

    // MARK: - Control

    func start() {
        guard stream == nil else { return }
        let listener = EventListener { [weak self] paths in
            Task { @MainActor [weak self] in self?.changed(paths) }
        }
        self.listener = listener
        var context = FSEventStreamContext(version: 0, info: Unmanaged.passUnretained(listener).toOpaque(),
                                           retain: nil, release: nil, copyDescription: nil)
        let flags = FSEventStreamCreateFlags(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagNoDefer)
        guard let stream = FSEventStreamCreate(nil, Self.callback, &context, [watchRoot] as CFArray,
                                               FSEventStreamEventId(kFSEventStreamEventIdSinceNow), 0.25, flags) else {
            changeSet?.trackingError = "Cannot watch \(root)"
            return
        }
        FSEventStreamSetDispatchQueue(stream, Self.queue)
        FSEventStreamStart(stream)
        self.stream = stream
        scheduleRefresh(after: Self.runDelay)
    }

    func stop() {
        debounce?.cancel()
        debounce = nil
        if let stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            self.stream = nil
        }
        listener = nil
    }

    /// The CLI run that created the changeset has delivered all its files.
    func runCompleted() {
        guard stream != nil else { return }
        scheduleRefresh(after: Self.settleDelay)
    }

    // MARK: - Events

    private static let queue = DispatchQueue(label: "dev.diffit.repotracker", qos: .utility)

    private static let callback: FSEventStreamCallback = { _, info, _, eventPaths, _, _ in
        guard let info else { return }
        let listener = Unmanaged<EventListener>.fromOpaque(info).takeUnretainedValue()
        let array = Unmanaged<CFArray>.fromOpaque(eventPaths).takeUnretainedValue()
        listener.handler((array as? [String]) ?? [])
    }

    private final class EventListener: @unchecked Sendable {
        let handler: @Sendable ([String]) -> Void
        init(handler: @escaping @Sendable ([String]) -> Void) { self.handler = handler }
    }

    private func changed(_ paths: [String]) {
        guard paths.contains(where: { !isInsideGitDirectory($0) }) else { return }
        scheduleRefresh(after: Self.settleDelay)
    }

    /// Paths below `.git/` are git's own bookkeeping (objects, logs, packed refs); `.git/` itself
    /// is reported when the index or HEAD is written, which can change the comparison.
    private func isInsideGitDirectory(_ path: String) -> Bool {
        var trimmed = Substring(path)
        while trimmed.hasSuffix("/") { trimmed = trimmed.dropLast() }
        return trimmed.hasPrefix(watchRoot + "/.git/")
    }

    private func scheduleRefresh(after delay: Duration) {
        debounce?.cancel()
        debounce = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            await self?.refresh()
        }
    }

    // MARK: - Refresh

    private func refresh() async {
        guard let changeSet, stream != nil else { return }
        if refreshing {
            refreshPending = true
            return
        }
        refreshing = true
        defer {
            refreshing = false
            if refreshPending {
                refreshPending = false
                scheduleRefresh(after: .milliseconds(50))
            }
        }
        // Blob ids of the entries the CLI created are unknown; hashing their snapshots lets the
        // first refresh keep them instead of replacing them.
        let hashRequests = changeSet.files.compactMap { entry -> HashRequest? in
            let oldPath = entry.oldBlob == nil ? entry.old.flatMap { $0.isLive ? nil : $0.path } : nil
            let newPath = entry.newBlob == nil ? entry.new.flatMap { $0.isLive ? nil : $0.path } : nil
            guard oldPath != nil || newPath != nil else { return nil }
            return HashRequest(id: entry.id, oldPath: oldPath, newPath: newPath)
        }
        let input = Input(root: root, arguments: arguments, comparison: comparison,
                          snapshotDirectory: snapshotDirectory, hashRequests: hashRequests)
        let outcome = await Task.detached(priority: .utility) { Self.compute(input) }.value
        guard stream != nil else { return }   // stopped meanwhile
        switch outcome {
        case .failure(let message):
            changeSet.trackingError = message
        case .success(let update):
            comparison = update.comparison
            changeSet.trackingError = nil
            for (id, hashes) in update.hashes {
                guard let entry = changeSet.files.first(where: { $0.id == id }) else { continue }
                if let old = hashes.old { entry.oldBlob = old }
                if let new = hashes.new { entry.newBlob = new }
            }
            AppModel.shared.apply(update.items, to: changeSet, root: root, snapshotDirectory: snapshotDirectory)
        }
    }

    // MARK: - Items

    /// One file of the comparison as git reports it now.
    struct Item: Sendable {
        enum NewSide: Sendable, Equatable {
            case none            // deleted
            case live            // the working-tree file
            case blob(String)    // a snapshot of this blob
        }
        var path: String
        var oldBlob: String?
        var new: NewSide

        /// Whether `entry` already shows exactly this.
        @MainActor func matches(_ entry: FileEntry) -> Bool {
            guard entry.oldBlob == oldBlob, (entry.old == nil) == (oldBlob == nil) else { return false }
            switch new {
            case .none: return entry.new == nil
            case .live: return entry.new?.isLive == true
            case .blob(let sha): return entry.new?.isLive == false && entry.newBlob == sha
            }
        }
    }

    // MARK: - Computation (off the main actor)

    private struct Comparison: Sendable {
        var arguments: [String]
        /// Path arguments, for listing untracked files within the same scope.
        var pathspecs: [String]
        /// False for `--cached` and two-revision comparisons: nothing on disk is a side then.
        var includesWorkingTree: Bool
    }

    private struct HashRequest: Sendable {
        var id: FileEntry.ID
        var oldPath: String?
        var newPath: String?
    }

    private struct Hashes: Sendable {
        var old: String?
        var new: String?
    }

    private struct Input: Sendable {
        var root: String
        var arguments: [String]
        var comparison: Comparison?
        var snapshotDirectory: URL
        var hashRequests: [HashRequest]
    }

    private struct Update: Sendable {
        var comparison: Comparison
        var items: [Item]
        var hashes: [(FileEntry.ID, Hashes)]
    }

    private enum Outcome: Sendable {
        case success(Update)
        case failure(String)
    }

    private struct TrackingError: Error {
        var message: String
    }

    private nonisolated static func compute(_ input: Input) -> Outcome {
        guard let executable = GitRunner.executable else { return .failure("git not found") }
        let git = GitRunner(executable: executable, root: input.root)
        do {
            guard let comparison = try input.comparison ?? classify(input.arguments, git: git) else {
                return .failure("this comparison does not involve the repository")
            }
            let raw = try git.run(["diff", "--raw", "-z", "--no-abbrev", "--no-color", "--no-ext-diff"] + comparison.arguments)
            guard raw.status == 0 else { throw TrackingError(message: "git diff: \(raw.stderr)") }
            var items = parseRaw(raw.stdout, live: comparison.includesWorkingTree)
            if comparison.includesWorkingTree {
                let scope = comparison.pathspecs.isEmpty ? [] : ["--"] + comparison.pathspecs
                let others = try git.run(["ls-files", "--others", "--exclude-standard", "-z"] + scope)
                guard others.status == 0 else { throw TrackingError(message: "git ls-files: \(others.stderr)") }
                let known = Set(items.map(\.path))
                for path in nulSeparated(others.stdout) where !known.contains(path) {
                    items.append(Item(path: path, oldBlob: nil, new: .live))
                }
            }
            try extractBlobs(for: items, git: git, into: input.snapshotDirectory)
            let hashes = input.hashRequests.map { request in
                (request.id, Hashes(old: request.oldPath.flatMap(blobHash), new: request.newPath.flatMap(blobHash)))
            }
            return .success(Update(comparison: comparison, items: items, hashes: hashes))
        } catch let error as TrackingError {
            return .failure(error.message)
        } catch {
            return .failure(error.localizedDescription)
        }
    }

    /// Which arguments are revisions and which are paths, and so whether the working tree is a
    /// side. git itself answers for each candidate; a range (`A..B`) counts as two revisions.
    private nonisolated static func classify(_ arguments: [String], git: GitRunner) throws -> Comparison? {
        if arguments.contains("--no-index") { return nil }
        let cached = arguments.contains { $0 == "--cached" || $0 == "--staged" }
        var candidates = arguments[...]
        var pathspecs: [String] = []
        if let dash = arguments.firstIndex(of: "--") {
            candidates = arguments[..<dash]
            pathspecs = Array(arguments[(dash + 1)...])
        }
        var revisions = 0
        for argument in candidates where !argument.hasPrefix("-") {
            if argument.contains("..") {
                revisions += 2
            } else if try git.run(["rev-parse", "--verify", "--quiet", "--end-of-options", argument]).status == 0 {
                revisions += 1
            } else {
                pathspecs.append(argument)
            }
        }
        return Comparison(arguments: arguments, pathspecs: pathspecs, includesWorkingTree: !cached && revisions <= 1)
    }

    /// `git diff --raw -z`: `:<old mode> <new mode> <old sha> <new sha> <status>` NUL path NUL,
    /// with a second path for renames and copies. An all-zero sha is "no content" (added or
    /// deleted) or, on the new side of a working-tree comparison, "the file on disk".
    private nonisolated static func parseRaw(_ data: Data, live: Bool) -> [Item] {
        let fields = nulSeparated(data)
        var items: [Item] = []
        var index = 0
        while index < fields.count {
            let header = fields[index]
            guard header.hasPrefix(":"), index + 1 < fields.count else { index += 1; continue }
            let parts = header.dropFirst().split(separator: " ")
            guard parts.count >= 5 else { index += 1; continue }
            let oldMode = parts[0], newMode = parts[1]
            let oldSHA = String(parts[2]), newSHA = String(parts[3])
            let status = parts[4].first ?? "M"
            var path = fields[index + 1]
            index += 2
            if status == "R" || status == "C", index < fields.count {
                path = fields[index]   // the destination
                index += 1
            }
            if oldMode == "160000" || newMode == "160000" { continue }   // submodules have no blob
            let old = isZero(oldSHA) ? nil : oldSHA
            let new: Item.NewSide
            if status == "D" {
                new = .none
            } else if live {
                new = .live
            } else {
                new = isZero(newSHA) ? .none : .blob(newSHA)
            }
            items.append(Item(path: path, oldBlob: old, new: new))
        }
        return items
    }

    private nonisolated static func isZero(_ sha: String) -> Bool {
        sha.allSatisfy { $0 == "0" }
    }

    private nonisolated static func nulSeparated(_ data: Data) -> [String] {
        data.split(separator: 0, omittingEmptySubsequences: true).map { String(decoding: $0, as: UTF8.self) }
    }

    /// Writes every blob the items need that is not in the snapshot directory yet, one
    /// `git cat-file --batch` run for all of them. Files are named by blob id, so a blob shared
    /// by several refreshes (or files) is extracted once.
    private nonisolated static func extractBlobs(for items: [Item], git: GitRunner, into directory: URL) throws {
        let fm = FileManager.default
        var needed: Set<String> = []
        for item in items {
            if let old = item.oldBlob { needed.insert(old) }
            if case .blob(let sha) = item.new { needed.insert(sha) }
        }
        let missing = needed.filter { !fm.fileExists(atPath: directory.appendingPathComponent($0).path) }.sorted()
        guard !missing.isEmpty else { return }
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        let input = Data((missing.joined(separator: "\n") + "\n").utf8)
        let output = try git.run(["cat-file", "--batch"], stdin: input)
        guard output.status == 0 else { throw TrackingError(message: "git cat-file: \(output.stderr)") }
        let data = output.stdout
        var cursor = data.startIndex
        while cursor < data.endIndex {
            guard let newline = data[cursor...].firstIndex(of: 0x0A) else { break }
            let header = String(decoding: data[cursor..<newline], as: UTF8.self).split(separator: " ")
            cursor = newline + 1
            // "<sha> blob <size>"; "<sha> missing" has no size and no body.
            guard header.count == 3, let size = Int(header[2]) else { continue }
            let end = min(cursor + size, data.endIndex)
            try data[cursor..<end].write(to: directory.appendingPathComponent(String(header[0])), options: .atomic)
            cursor = min(end + 1, data.endIndex)   // the newline after the body
        }
    }

    /// git's blob id of a file's content.
    private nonisolated static func blobHash(of path: String) -> String? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return nil }
        var hasher = Insecure.SHA1()
        hasher.update(data: Data("blob \(data.count)\u{0}".utf8))
        hasher.update(data: data)
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
