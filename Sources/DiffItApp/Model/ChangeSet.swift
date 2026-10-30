import Foundation

/// One `git difftool` run (or one hand-run comparison).
@MainActor @Observable
final class ChangeSet: Identifiable {
    let id = UUID()
    let key: String
    var title: String
    let createdAt: Date
    var expectedCount: Int?
    /// The `git diff` arguments of the run that created this changeset; nil when it was not git
    /// that invoked the CLI. With them the changeset follows the repository (`RepoTracker`).
    let gitDiffArguments: [String]?
    var tracker: RepoTracker?
    /// Why the changeset is not following the repository, when it should be.
    var trackingError: String?
    var files: [FileEntry] = []
    /// Directories the CLI created for this changeset; deleted when it closes.
    var snapshotDirectories: Set<String> = []
    /// Rebuilt when `files` changes.
    private(set) var tree: [FileTreeNode] = []
    /// Changes whenever a directory node appears, disappears or is renamed (compressed chains
    /// split as siblings arrive). The sidebar rebuilds the changeset's rows on such a change
    /// instead of diffing them: the outline view leaves rows behind when nodes move between
    /// parents, drawing stale rows over live ones.
    private(set) var structureKey = ""

    init(key: String, title: String, createdAt: Date = Date(), expectedCount: Int?, gitDiffArguments: [String]? = nil) {
        self.key = key
        self.title = title
        self.createdAt = createdAt
        self.expectedCount = expectedCount
        self.gitDiffArguments = gitDiffArguments
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
        rebuildTree()
        return replaced
    }

    /// Drops an entry (its file left the comparison) and rebuilds the tree.
    func remove(_ entry: FileEntry) {
        guard let index = files.firstIndex(where: { $0.id == entry.id }) else { return }
        files.remove(at: index)
        rebuildTree()
    }

    private func rebuildTree() {
        tree = FileTreeBuilder.build(files)
        structureKey = FileTreeBuilder.structureKey(tree)
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
