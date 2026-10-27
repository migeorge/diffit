import SwiftUI

struct MainView: View {
    var body: some View {
        NavigationSplitView {
            List {}
                .navigationSplitViewColumnWidth(min: 200, ideal: 260)
        } detail: {
            ContentUnavailableView("No Changes", systemImage: "doc.text.magnifyingglass",
                                   description: Text("Run `git difftool` to open a changeset."))
        }
        .navigationTitle("DiffIt")
    }
}
