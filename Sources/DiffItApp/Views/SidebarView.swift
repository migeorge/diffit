import SwiftUI

struct SidebarView: View {
    @Environment(AppModel.self) private var model
    /// Directory nodes the user collapsed; everything else is expanded by default.
    @State private var collapsed: Set<String> = []

    var body: some View {
        @Bindable var model = model
        List(selection: $model.selection) {
            ForEach(model.changeSets) { changeSet in
                Section {
                    ForEach(changeSet.tree) { node in
                        FileTreeNodeView(node: node, scope: changeSet.id.uuidString, collapsed: $collapsed)
                    }
                } header: {
                    ChangeSetHeader(changeSet: changeSet)
                }
            }
        }
        .listStyle(.sidebar)
    }
}

// MARK: - Section header

private struct ChangeSetHeader: View {
    @Environment(AppModel.self) private var model
    let changeSet: ChangeSet

    var body: some View {
        HStack(spacing: 6) {
            Text(changeSet.title)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 4)
            if changeSet.isLoading {
                ProgressView().controlSize(.mini)
            }
            DiffCounts(additions: changeSet.additions, deletions: changeSet.deletions)
            Button {
                model.close(changeSet)
            } label: {
                Image(systemName: "xmark.circle")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Close changeset")
        }
    }
}

// MARK: - Tree rows

private struct FileTreeNodeView: View {
    let node: FileTreeNode
    let scope: String
    @Binding var collapsed: Set<String>

    private var key: String { scope + "/" + node.id }

    var body: some View {
        if let children = node.children {
            DisclosureGroup(isExpanded: Binding(
                get: { !collapsed.contains(key) },
                set: { expanded in if expanded { collapsed.remove(key) } else { collapsed.insert(key) } }
            )) {
                ForEach(children) { child in
                    FileTreeNodeView(node: child, scope: scope, collapsed: $collapsed)
                }
            } label: {
                Label(node.name, systemImage: "folder")
            }
        } else if let entry = node.entry {
            FileRow(entry: entry)
                .tag(entry.id)
        }
    }
}

private struct FileRow: View {
    let entry: FileEntry

    var body: some View {
        HStack(spacing: 6) {
            Label(entry.fileName, systemImage: symbol)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 4)
            if entry.isLoading {
                ProgressView().controlSize(.mini)
            } else if entry.error != nil {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                    .help(entry.error ?? "")
            }
            DiffCounts(additions: entry.additions, deletions: entry.deletions)
        }
    }

    private var symbol: String {
        switch entry.status {
        case .added: "doc.badge.plus"
        case .deleted: "trash"   // there is no doc.badge.minus symbol
        case .modified: "doc.text"
        case .binary: "doc.zipper"
        case .unreadable: "doc.questionmark"
        }
    }
}

/// `+N` in green, `−M` in red, monospaced digits.
struct DiffCounts: View {
    let additions: Int
    let deletions: Int

    var body: some View {
        HStack(spacing: 4) {
            if additions > 0 {
                Text("+\(additions)").foregroundStyle(.green)
            }
            if deletions > 0 {
                Text("−\(deletions)").foregroundStyle(.red)
            }
        }
        .font(.caption.monospacedDigit())
    }
}
