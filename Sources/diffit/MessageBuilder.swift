import Foundation
import DiffItProtocol

/// Builds the `OpenMessage` for a compare invocation (per-file or directory mode).
struct MessageBuilder {
    let options: CLIOptions
    let environment: [String: String]
    let snapshotter: Snapshotter

    private static let nullDevice = "/dev/null"

    func build(old: String, new: String, displayPath: String?) throws -> OpenMessage {
        let oldExists = old != Self.nullDevice
        let newExists = new != Self.nullDevice
        guard oldExists || newExists else { throw CLIError.usage("both sides are /dev/null") }

        var isDir: ObjCBool = false
        let fm = FileManager.default
        let oldIsDir = oldExists && fm.fileExists(atPath: old, isDirectory: &isDir) && isDir.boolValue
        let newIsDir = newExists && fm.fileExists(atPath: new, isDirectory: &isDir) && isDir.boolValue
        if oldIsDir && newIsDir {
            return try directoryMessage(old: old, new: new)
        }
        if oldIsDir != newIsDir {
            throw CLIError.usage("cannot compare a directory with a file")
        }
        return try fileMessage(old: oldExists ? old : nil, new: newExists ? new : nil, displayPath: displayPath)
    }

    // MARK: - Per-file mode

    private func fileMessage(old: String?, new: String?, displayPath: String?) throws -> OpenMessage {
        let counter = environment["GIT_DIFF_PATH_COUNTER"].flatMap(Int.init)
        let total = environment["GIT_DIFF_PATH_TOTAL"].flatMap(Int.init)
        let display = displayPath ?? URL(fileURLWithPath: new ?? old ?? "").lastPathComponent
        let file = try makeFile(displayPath: display, old: old, new: new)
        let (key, title) = changeSetIdentity(invokedByGit: counter != nil)
        return OpenMessage(
            changeSetKey: key,
            changeSetTitle: options.title ?? title,
            startsNewChangeSet: counter == nil || counter == 1,
            expectedCount: total,
            snapshotDirectory: snapshotter.directory?.path,
            files: [file],
            gitDiffArguments: GitInvocation.diffArguments()
        )
    }

    // MARK: - Directory mode

    private func directoryMessage(old: String, new: String) throws -> OpenMessage {
        let oldRoot = URL(fileURLWithPath: old), newRoot = URL(fileURLWithPath: new)
        let oldPaths = Self.relativeFiles(under: oldRoot), newPaths = Self.relativeFiles(under: newRoot)
        let all = Set(oldPaths).union(newPaths).sorted()
        var files: [FileMessage] = []
        files.reserveCapacity(all.count)
        for relative in all {
            let o = oldPaths.contains(relative) ? oldRoot.appendingPathComponent(relative).path : nil
            let n = newPaths.contains(relative) ? newRoot.appendingPathComponent(relative).path : nil
            files.append(try makeFile(displayPath: relative, old: o, new: n))
        }
        let (key, title) = changeSetIdentity(invokedByGit: false)
        return OpenMessage(
            changeSetKey: key,
            changeSetTitle: options.title ?? title,
            startsNewChangeSet: true,
            expectedCount: files.count,
            snapshotDirectory: snapshotter.directory?.path,
            files: files,
            gitDiffArguments: GitInvocation.diffArguments()
        )
    }

    /// Regular files and symlinks below `root`, as slash-separated relative paths. Skips `.git`.
    private static func relativeFiles(under root: URL) -> Set<String> {
        var result: Set<String> = []
        let keys: [URLResourceKey] = [.isDirectoryKey, .isSymbolicLinkKey, .isRegularFileKey]
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: keys) else {
            return result
        }
        let rootPath = root.standardizedFileURL.path
        for case let url as URL in enumerator {
            let values = try? url.resourceValues(forKeys: Set(keys))
            if url.lastPathComponent == ".git" {
                enumerator.skipDescendants()
                continue
            }
            let isSymlink = values?.isSymbolicLink ?? false
            let isDirectory = (values?.isDirectory ?? false) && !isSymlink
            if isDirectory { continue }
            let path = url.standardizedFileURL.path
            guard path.hasPrefix(rootPath + "/") else { continue }
            result.insert(String(path.dropFirst(rootPath.count + 1)))
        }
        return result
    }

    // MARK: - Shared

    private func makeFile(displayPath: String, old: String?, new: String?) throws -> FileMessage {
        let oldSide = try old.map {
            try snapshotter.side(for: $0, label: options.oldLabel, liveLabel: "Original", snapshotLabel: "Original", slot: "old")
        }
        let newSide = try new.map {
            try snapshotter.side(for: $0, label: options.newLabel, liveLabel: "Working copy", snapshotLabel: "Changed", slot: "new")
        }
        return FileMessage(displayPath: displayPath, old: oldSide, new: newSide)
    }

    /// git runs external diffs from the top of the working tree, so when it invoked us the
    /// current directory already is the repo root and the `rev-parse` round trip can be skipped.
    private func changeSetIdentity(invokedByGit: Bool) -> (key: String, title: String) {
        let cwd = FileManager.default.currentDirectoryPath
        let key = invokedByGit ? cwd : (Git.topLevel() ?? cwd)
        return (key, URL(fileURLWithPath: key).lastPathComponent)
    }
}
