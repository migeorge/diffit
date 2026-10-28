import Foundation
import DiffItProtocol

@MainActor @Observable
final class AppModel {
    static let shared = AppModel()

    /// Newest first.
    var changeSets: [ChangeSet] = []
    var selection: FileEntry.ID? {
        didSet { ensureSelectedIsWatched() }
    }

    /// Descriptor budget: beyond this many watched files, only the selected file is watched.
    static let watcherLimit = 1_000
    private var watchedCount = 0

    /// Called when a message starts a new changeset; the app delegate shows and activates the window.
    @ObservationIgnored var onNewChangeSet: (() -> Void)?

    /// The pair view currently on screen, so menu commands can drive change navigation.
    @ObservationIgnored weak var activeNavigator: (any DiffNavigator)? {
        didSet { hasActiveNavigator = activeNavigator != nil }
    }
    /// Observable mirror of `activeNavigator` for menu enabling.
    var hasActiveNavigator = false
    /// Mirror of the navigator's position for the toolbar indicator and menu enabling.
    var changeNavigation = ChangeNavigationState.none

    var selectedEntry: FileEntry? {
        guard let selection else { return nil }
        for cs in changeSets {
            if let entry = cs.files.first(where: { $0.id == selection }) { return entry }
        }
        return nil
    }

    var selectedChangeSet: ChangeSet? {
        guard let selection else { return nil }
        return changeSets.first { cs in cs.files.contains { $0.id == selection } }
    }

    // MARK: - Ingest

    func ingest(_ message: OpenMessage) -> Ack {
        guard message.version == OpenMessage.currentVersion else {
            return Ack(ok: false, error: "diffit CLI protocol version \(message.version) does not match the app (\(OpenMessage.currentVersion)); reinstall the command line tool from the DiffIt menu")
        }

        let changeSet: ChangeSet
        let isNew: Bool
        if !message.startsNewChangeSet, let existing = changeSets.first(where: { $0.key == message.changeSetKey }) {
            changeSet = existing
            isNew = false
        } else {
            changeSet = ChangeSet(key: message.changeSetKey,
                                  title: Self.title(message.changeSetTitle, at: Date()),
                                  expectedCount: message.expectedCount)
            changeSets.insert(changeSet, at: 0)
            isNew = true
        }
        if let dir = message.snapshotDirectory { changeSet.snapshotDirectories.insert(dir) }
        if let count = message.expectedCount { changeSet.expectedCount = count }

        var firstEntry: FileEntry?
        for file in message.files {
            let entry = FileEntry(displayPath: file.displayPath, old: file.old, new: file.new)
            if let replaced = changeSet.upsert(entry) { stopWatching(replaced) }
            DiffLoader.load(entry)
            if watchedCount < Self.watcherLimit { startWatching(entry) }
            if firstEntry == nil { firstEntry = entry }
        }

        if isNew {
            selection = changeSet.orderedFiles.first?.id ?? firstEntry?.id
            onNewChangeSet?()
        }
        return Ack(ok: true)
    }

    static func title(_ base: String, at date: Date) -> String {
        "\(base) · \(date.formatted(date: .omitted, time: .shortened))"
    }

    // MARK: - Closing

    /// Removes the changeset, stops its watchers and deletes its snapshot directories
    /// (the app's own cache; never user files).
    func close(_ changeSet: ChangeSet) {
        guard let index = changeSets.firstIndex(where: { $0.id == changeSet.id }) else { return }
        let wasSelected = changeSet.files.contains { $0.id == selection }
        changeSets.remove(at: index)
        for entry in changeSet.files { stopWatching(entry) }
        let fm = FileManager.default
        let root = DiffItPaths.snapshotsRoot().path
        for dir in changeSet.snapshotDirectories where dir.hasPrefix(root) {
            try? fm.removeItem(atPath: dir)
        }
        if wasSelected {
            selection = changeSets.first?.orderedFiles.first?.id
        }
    }

    func closeSelectedChangeSet() {
        if let cs = selectedChangeSet ?? changeSets.first { close(cs) }
    }

    // MARK: - Watching

    /// Starts one watcher per live side. A change reloads the diff; a vanished file keeps the
    /// last diff and surfaces an error while the watcher keeps polling for its return.
    private func startWatching(_ entry: FileEntry) {
        guard entry.watchers.isEmpty else { return }
        for side in entry.liveSides {
            let watcher = FileWatcher(
                path: side.path,
                onChange: { Task { @MainActor in DiffLoader.load(entry) } },
                onMissing: { Task { @MainActor in entry.error = "File removed: \(side.path)" } }
            )
            if watcher.start() {
                entry.watchers.append(watcher)
            } else {
                entry.error = "Cannot watch \(side.path)"
            }
        }
        if !entry.watchers.isEmpty { watchedCount += 1 }
    }

    private func stopWatching(_ entry: FileEntry) {
        guard !entry.watchers.isEmpty else { return }
        for watcher in entry.watchers { watcher.stop() }
        entry.watchers = []
        watchedCount -= 1
    }

    /// Over the descriptor budget, files are only watched while selected.
    private func ensureSelectedIsWatched() {
        guard let entry = selectedEntry, !entry.isWatched, !entry.liveSides.isEmpty else { return }
        startWatching(entry)
        DiffLoader.load(entry)   // it may have changed while unwatched
    }

    func stopAllWatchers() {
        for cs in changeSets { for entry in cs.files { stopWatching(entry) } }
    }

    // MARK: - Navigation

    private var allFiles: [FileEntry] { changeSets.flatMap(\.orderedFiles) }

    func selectNextFile() { step(by: 1) }
    func selectPreviousFile() { step(by: -1) }

    private func step(by delta: Int) {
        let files = allFiles
        guard !files.isEmpty else { return }
        guard let current = files.firstIndex(where: { $0.id == selection }) else {
            selection = files[0].id
            return
        }
        let next = current + delta
        guard files.indices.contains(next) else { return }
        selection = files[next].id
    }

    /// Re-diffs every loaded file (a diff option changed).
    func reloadAll() {
        for entry in allFiles where entry.result != nil { DiffLoader.load(entry) }
    }

    /// Reloads the selected file, starting its watchers if it is over the budget and unwatched.
    func reloadSelected() {
        guard let entry = selectedEntry else { return }
        if !entry.isWatched, !entry.liveSides.isEmpty, watchedCount < Self.watcherLimit {
            startWatching(entry)
        }
        DiffLoader.load(entry)
    }
}
