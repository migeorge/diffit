import SwiftUI

struct SidebarView: View {
    @Environment(AppModel.self) private var model
    /// Directory nodes the user collapsed; everything else is expanded by default.
    @State private var collapsed: Set<String> = []

    var body: some View {
        // Selection goes through the model (see `AppModel.sidebarSelection`); read here, in the
        // body, so the view follows it. The list writes nil when rows it had selected are rebuilt;
        // deselecting is not a feature here, so nil is ignored.
        let highlighted = model.sidebarSelection
        let selection = Binding(get: { highlighted }, set: { if let id = $0 { model.selection = id } })
        List(selection: selection) {
            ForEach(model.changeSets) { changeSet in
                Section {
                    ForEach(changeSet.tree) { node in
                        FileTreeNodeView(node: node, scope: changeSet.id.uuidString, collapsed: $collapsed)
                    }
                } header: {
                    ChangeSetHeader(changeSet: changeSet)
                }
                // New identity when the directories change, so the rows are rebuilt rather than
                // diffed (see `ChangeSet.structureKey`). Files joining an existing directory
                // still update in place.
                .id(changeSet.id.uuidString + changeSet.structureKey)
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
                    // Only files are selectable; a folder row neither highlights nor changes the
                    // selection. On the label, not the group: there it would cover the children too.
                    .selectionDisabled()
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
            Label(entry.fileName, systemImage: entry.systemImage)
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
