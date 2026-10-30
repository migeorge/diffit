import Foundation

/// A sidebar node: a directory (possibly a compressed chain like `src/app/models`) or a file.
struct FileTreeNode: Identifiable {
    /// Full path of the node within the changeset; unique.
    let id: String
    /// Text shown in the row.
    let name: String
    /// Present for file nodes only.
    let entry: FileEntry?
    /// nil for files; directories always have an array (possibly empty).
    let children: [FileTreeNode]?

    var isDirectory: Bool { children != nil }
}

@MainActor
enum FileTreeBuilder {
    private final class Directory {
        var subdirectories: [String: Directory] = [:]
        var files: [(name: String, entry: FileEntry)] = []
    }

    /// Splits display paths on `/`, inserts into a trie, compresses single-child directory
    /// chains, and sorts directories first then files, case-insensitively.
    static func build(_ entries: [FileEntry]) -> [FileTreeNode] {
        let root = Directory()
        for entry in entries {
            let components = entry.displayPath.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
            guard let fileName = components.last else { continue }
            var dir = root
            for component in components.dropLast() {
                if let next = dir.subdirectories[component] {
                    dir = next
                } else {
                    let next = Directory()
                    dir.subdirectories[component] = next
                    dir = next
                }
            }
            dir.files.append((fileName, entry))
        }
        return nodes(of: root, pathPrefix: "")
    }

    private static func nodes(of dir: Directory, pathPrefix: String) -> [FileTreeNode] {
        var result: [FileTreeNode] = []
        for (name, sub) in dir.subdirectories.sorted(by: { caseInsensitiveLess($0.key, $1.key) }) {
            var displayName = name
            var path = pathPrefix + name
            var current = sub
            // Compress chains that have exactly one child directory and no files.
            while current.files.isEmpty, current.subdirectories.count == 1,
                  let (childName, child) = current.subdirectories.first {
                displayName += "/" + childName
                path += "/" + childName
                current = child
            }
            result.append(FileTreeNode(id: path, name: displayName, entry: nil,
                                       children: nodes(of: current, pathPrefix: path + "/")))
        }
        for (name, entry) in dir.files.sorted(by: { caseInsensitiveLess($0.name, $1.name) }) {
            result.append(FileTreeNode(id: pathPrefix + name, name: name, entry: entry, children: nil))
        }
        return result
    }

    /// The directory ids of `nodes`, in order; equal for two trees with the same directories.
    static func structureKey(_ nodes: [FileTreeNode]) -> String {
        var ids: [String] = []
        func walk(_ nodes: [FileTreeNode]) {
            for node in nodes where node.isDirectory {
                ids.append(node.id)
                walk(node.children ?? [])
            }
        }
        walk(nodes)
        return ids.joined(separator: "\n")
    }

    private static func caseInsensitiveLess(_ a: String, _ b: String) -> Bool {
        let order = a.caseInsensitiveCompare(b)
        return order == .orderedAscending || (order == .orderedSame && a < b)
    }
}
