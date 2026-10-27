import SwiftUI

/// Phase 3 placeholder: shows what the model knows about the selected entry.
/// Phase 4 replaces the body with the side-by-side panes.
struct DiffDetailView: View {
    let entry: FileEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(entry.displayPath)
                .font(.title3.weight(.semibold))
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                row("Status", "\(entry.status)")
                row("Old", entry.old.map { "\($0.label) — \($0.path)\($0.isLive ? " (live)" : "")" } ?? "—")
                row("New", entry.new.map { "\($0.label) — \($0.path)\($0.isLive ? " (live)" : "")" } ?? "—")
                if let result = entry.result {
                    row("Rows", "\(result.rows.count) rows, \(result.changeBlocks.count) change blocks")
                    row("Changes", "+\(result.additions) −\(result.deletions)")
                    row("Identical", result.isIdentical ? "yes" : "no")
                }
                row("Generation", "\(entry.generation)")
                if let error = entry.error {
                    row("Error", error)
                }
            }
            .font(.system(.body, design: .monospaced))
            .textSelection(.enabled)
            if entry.isLoading {
                ProgressView("Diffing…")
            }
            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private func row(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label).foregroundStyle(.secondary).gridColumnAlignment(.trailing)
            Text(value).lineLimit(2).truncationMode(.middle)
        }
    }
}
