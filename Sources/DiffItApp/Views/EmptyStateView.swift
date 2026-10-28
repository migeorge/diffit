import SwiftUI

struct EmptyStateView: View {
    private let installer = CLIInstaller.shared

    var body: some View {
        VStack(spacing: 16) {
            ContentUnavailableView {
                Label("No Changes", systemImage: "doc.text.magnifyingglass")
            } description: {
                Text("Run `git difftool` in a repository, or `diffit OLD NEW` from a terminal.")
            }
            switch installer.status {
            case .incomplete:
                InstallCard(installer: installer)
            case .unavailable:
                UnbundledNote()
            case .installed, .unknown:
                EmptyView()
            }
            if let message = installer.message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(message.hasPrefix("Failed") ? AnyShapeStyle(.red) : AnyShapeStyle(.secondary))
                    .frame(maxWidth: 520)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task { installer.refresh() }
    }
}

/// Shown until the command line tool and git are set up.
private struct InstallCard: View {
    let installer: CLIInstaller

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Set up the command line tool")
                .font(.headline)
            Text("Installing will:")
                .font(.caption)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 4) {
                Label("link ~/.local/bin/diffit to the tool inside this app", systemImage: "link")
                Label("set git's global diff.tool to diffit (difftool.diffit.cmd, difftool.prompt)", systemImage: "gearshape")
            }
            .font(.caption)
            Text("You can undo this later from DiffIt ▸ Remove Command Line Tool.")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Button("Install Command Line Tool") { Task { await installer.install() } }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!installer.canInstall)
                if installer.isBusy { ProgressView().controlSize(.small) }
            }
            .padding(.top, 4)
        }
        .padding(14)
        .frame(maxWidth: 520, alignment: .leading)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }
}

/// `swift run` builds have no bundled CLI; show the manual setup instead.
private struct UnbundledNote: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("This build has no bundled command line tool. From a source checkout, install the app and use its Install button:")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("make install && open /Applications/DiffIt.app")
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .padding(10)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
        }
        .frame(maxWidth: 520)
    }
}
