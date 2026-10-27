import Foundation

/// One `git difftool` run (or one hand-run comparison).
@MainActor @Observable
final class ChangeSet: Identifiable {
    let id = UUID()
    let key: String
    var title: String
    let createdAt: Date
    var expectedCount: Int?
    var files: [FileEntry] = []
    /// Directories the CLI created for this changeset; deleted when it closes.
    var snapshotDirectories: Set<String> = []
    /// Rebuilt when `files` changes.
    private(set) var tree: [FileTreeNode] = []

    init(key: String, title: String, createdAt: Date = Date(), expectedCount: Int?) {
        self.key = key
        self.title = title
        self.createdAt = createdAt
        self.expectedCount = expectedCount
    }

    var additions: Int { files.reduce(0) { $0 + $1.additions } }
    var deletions: Int { files.reduce(0) { $0 + $1.deletions } }
    var isLoading: Bool { files.contains { $0.isLoading } }

    /// Adds or replaces (by display path) an entry and rebuilds the tree.
    func upsert(_ entry: FileEntry) -> FileEntry? {
        var replaced: FileEntry?
        if let index = files.firstIndex(where: { $0.displayPath == entry.displayPath }) {
            replaced = files[index]
            files[index] = entry
        } else {
            files.append(entry)
        }
        tree = FileTreeBuilder.build(files)
        return replaced
    }

    /// Files in sidebar (tree) order, for next/previous navigation.
    var orderedFiles: [FileEntry] {
        var out: [FileEntry] = []
        func walk(_ nodes: [FileTreeNode]) {
            for node in nodes {
                if let entry = node.entry { out.append(entry) }
                if let children = node.children { walk(children) }
            }
        }
        walk(tree)
        return out
    }
}
