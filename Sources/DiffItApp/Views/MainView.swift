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
    }
}
