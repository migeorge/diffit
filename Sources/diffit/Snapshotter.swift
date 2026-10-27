import Foundation
import DiffItProtocol

/// Decides whether a path is one of git's temp files and, if so, copies it somewhere durable
/// before the CLI returns (git deletes `$LOCAL`/`$REMOTE` the moment we exit).
final class Snapshotter {
    private(set) var directory: URL?
    private var counter = 0

    private static let temporaryPrefixes: [String] = {
        var prefixes = ["/private/tmp", "/tmp", "/private/var/folders", "/var/folders"]
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).resolvingSymlinksInPath().path
        prefixes.append(tmp.hasSuffix("/") ? String(tmp.dropLast()) : tmp)
        return prefixes
    }()

    // MARK: - Classification

    static func isTemporary(_ path: String) -> Bool {
        let resolved = URL(fileURLWithPath: path).resolvingSymlinksInPath().path
        for prefix in temporaryPrefixes where resolved == prefix || resolved.hasPrefix(prefix + "/") {
            return true
        }
        return resolved.split(separator: "/").contains { $0.hasPrefix("git-blob-") || $0.hasPrefix("git-difftool.") }
    }

    // MARK: - Snapshotting

    /// Returns the side to send: a snapshot copy for temp files, the path itself (resolved) for live files.
    func side(for path: String, label: String?, liveLabel: String, snapshotLabel: String, slot: String) throws -> FileSide {
        let resolved = URL(fileURLWithPath: path).resolvingSymlinksInPath().path
        if Self.isTemporary(path) {
            let copy = try snapshot(resolved, slot: slot)
            return FileSide(path: copy, isLive: false, label: label ?? snapshotLabel)
        }
        return FileSide(path: resolved, isLive: true, label: label ?? liveLabel)
    }

    /// Removes the snapshot directory (used when the hand-off fails so nothing leaks).
    func discard() {
        if let directory { try? FileManager.default.removeItem(at: directory) }
        directory = nil
    }

    // MARK: - Private

    private func snapshot(_ source: String, slot: String) throws -> String {
        let dir = try ensureDirectory()
        counter += 1
        let basename = URL(fileURLWithPath: source).lastPathComponent
        let destination = dir.appendingPathComponent("\(counter)-\(slot)-\(basename)")
        let fm = FileManager.default
        do {
            try fm.copyItem(atPath: source, toPath: destination.path)
        } catch {
            let data = try Data(contentsOf: URL(fileURLWithPath: source))
            try data.write(to: destination, options: .atomic)
        }
        return destination.path
    }

    private func ensureDirectory() throws -> URL {
        if let directory { return directory }
        let root = DiffItPaths.snapshotsRoot()
        try DiffItPaths.ensureDirectory(root)
        let dir = root.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try DiffItPaths.ensureDirectory(dir)
        directory = dir
        return dir
    }
}
