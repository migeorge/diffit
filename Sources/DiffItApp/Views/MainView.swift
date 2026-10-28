import SwiftUI

struct MainView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 200, ideal: 280)
        } detail: {
            if model.tabs.isEmpty {
                EmptyStateView()
            } else {
                VStack(spacing: 0) {
                    TabBarView()
                    Divider()
                    tabContents
                }
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

// MARK: - Tabs

extension MainView {
    /// Every open tab stays built, so switching back keeps its scroll position and find state;
    /// only the active one is visible and hit-testable.
    private var tabContents: some View {
        ZStack {
            ForEach(model.tabs) { tab in
                if let entry = model.entry(for: tab) {
                    let isActive = tab.id == model.activeTabID
                    DiffDetailView(entry: entry, isActive: isActive)
                        .id(entry.id)
                        .opacity(isActive ? 1 : 0)
                        .zIndex(isActive ? 1 : 0)
                        .allowsHitTesting(isActive)
                        .accessibilityHidden(!isActive)
                }
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
        // The group is drawn as one pill around its items and the text gets no padding of its
        // own, so it needs an inset from the pill's leading edge; the pill sizes to the text.
        Text(indicator(state))
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .fixedSize()
            .padding(.leading, 10)
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
