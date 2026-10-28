import SwiftUI

/// The selected file: any banners, then the panes with their headers (each side's label and
/// change count; drawn by the pair view so they follow its divider).
struct DiffDetailView: View {
    @Environment(AppSettings.self) private var settings
    let entry: FileEntry

    var body: some View {
        VStack(spacing: 0) {
            banners
            content
        }
    }

    // MARK: - Header

    private var oldLabel: String { entry.old?.label ?? "No original" }
    private var newLabel: String { entry.new?.label ?? "Deleted" }

    /// Only the binary presentation has no pair view to draw the headers.
    private var header: some View {
        HStack(spacing: 0) {
            sideLabel(oldLabel, count: entry.deletions, sign: "−", color: .red)
            Divider().frame(height: 16)
            sideLabel(newLabel, count: entry.additions, sign: "+", color: .green)
        }
        .font(.callout)
        .padding(.vertical, 4)
        .background(.bar)
    }

    private func sideLabel(_ label: String, count: Int, sign: String, color: Color) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            if entry.isLoading {
                ProgressView().controlSize(.mini)
            } else if count > 0 {
                Text("\(sign)\(count)")
                    .foregroundStyle(color)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Banners

    @ViewBuilder
    private var banners: some View {
        if let error = entry.error {
            banner(error, symbol: "exclamationmark.triangle", tint: .orange)
        }
        if entry.intraLineDisabled {
            banner("Large file — intra-line highlighting disabled", symbol: "info.circle", tint: .secondary)
        }
        if entry.status == .modified, entry.result?.isIdentical == true {
            banner("Files are identical", symbol: "equal.circle", tint: .secondary)
        }
    }

    private func banner(_ text: String, symbol: String, tint: Color) -> some View {
        VStack(spacing: 0) {
            Label(text, systemImage: symbol)
                .font(.callout)
                .foregroundStyle(tint)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
            Divider()
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if entry.status == .binary {
            header
            Divider()
            binaryPlaceholder
        } else {
            DiffPairRepresentable(
                entryID: entry.id,
                generation: entry.generation,
                result: entry.result,
                lineMapping: entry.newLineMapping,
                oldSyntax: entry.oldSyntax,
                newSyntax: entry.newSyntax,
                oldPlaceholder: entry.old == nil ? "No original" : nil,
                newPlaceholder: entry.new == nil ? "Deleted" : nil,
                oldHeader: .init(label: oldLabel, count: entry.deletions, isLoading: entry.isLoading),
                newHeader: .init(label: newLabel, count: entry.additions, isLoading: entry.isLoading),
                font: settings.font,
                tabWidth: settings.tabWidth,
                intraLineHighlights: settings.intraLineHighlights,
                showChangeHatch: settings.showChangeHatch,
                settingsVersion: settings.version
            )
        }
    }

    private var binaryPlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.zipper").font(.largeTitle).foregroundStyle(.secondary)
            Text("Binary file").font(.title3)
            Text("\(sizeText(entry.oldSize)) → \(sizeText(entry.newSize))")
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func sizeText(_ bytes: Int?) -> String {
        guard let bytes else { return "—" }
        return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
}
