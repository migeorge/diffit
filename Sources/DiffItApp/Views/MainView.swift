import SwiftUI

struct MainView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 200, ideal: 280)
        } detail: {
            if let entry = model.selectedEntry {
                DiffDetailView(entry: entry)
                    .id(entry.id)
            } else {
                EmptyStateView()
            }
        }
        .navigationTitle(model.selectedEntry?.displayPath ?? "DiffIt")
        .navigationSubtitle(model.selectedChangeSet?.title ?? "")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                ChangeNavigationToolbar()
            }
        }
    }
}

// MARK: - Toolbar

/// Previous / next change with an "i / n" indicator, driven by the pair view on screen.
private struct ChangeNavigationToolbar: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let state = model.changeNavigation
        let hasEntry = model.selectedEntry != nil
        // The group is drawn as one pill around its items; the text gets no padding of its own, so
        // give it a fixed width that fits "No changes" and an inset from the pill's leading edge.
        Text(indicator(state))
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .fixedSize()
            .frame(width: 84, alignment: .trailing)
            .padding(.leading, 8)
            .opacity(hasEntry ? 1 : 0)
        Button {
            model.activeNavigator?.previousChange()
        } label: {
            Label("Previous Change", systemImage: "chevron.up")
        }
        .help("Previous Change (⌘↑)")
        .disabled(state.count == 0)
        Button {
            model.activeNavigator?.nextChange()
        } label: {
            Label("Next Change", systemImage: "chevron.down")
        }
        .help("Next Change (⌘↓)")
        .disabled(state.count == 0)
    }

    private func indicator(_ state: ChangeNavigationState) -> String {
        guard state.count > 0 else { return "No changes" }
        let current = state.current.map { String($0 + 1) } ?? "–"
        return "\(current) / \(state.count)"
    }
}
