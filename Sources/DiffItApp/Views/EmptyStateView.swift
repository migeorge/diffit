import SwiftUI

struct EmptyStateView: View {
    private let snippet = """
    git config --global diff.tool diffit
    git config --global difftool.diffit.cmd 'diffit "$LOCAL" "$REMOTE" "$MERGED"'
    git config --global difftool.prompt false
    """

    var body: some View {
        VStack(spacing: 16) {
            ContentUnavailableView {
                Label("No Changes", systemImage: "doc.text.magnifyingglass")
            } description: {
                Text("Run `git difftool` in a repository, or `diffit OLD NEW` from a terminal.")
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("One-time setup (or run `diffit --git-config`):")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(snippet)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(10)
                    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
            }
            .frame(maxWidth: 520)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
