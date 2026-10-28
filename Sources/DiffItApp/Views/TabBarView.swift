import SwiftUI

/// Open files across the top of the detail area. Click to switch, double-click to keep a
/// preview tab open, ⌘W or the ⓧ to close.
struct TabBarView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(model.tabs) { tab in
                        if let entry = model.entry(for: tab) {
                            TabItem(tab: tab, entry: entry, isActive: tab.id == model.activeTabID)
                                .id(tab.id)
                        }
                    }
                }
            }
            .onChange(of: model.activeTabID) { _, id in
                if let id { withAnimation(.easeOut(duration: 0.15)) { proxy.scrollTo(id) } }
            }
        }
        .frame(height: Self.height)
        .background(.bar)
    }

    static let height: CGFloat = 30
}

// MARK: - Tab

private struct TabItem: View {
    @Environment(AppModel.self) private var model
    let tab: DiffTab
    let entry: FileEntry
    let isActive: Bool
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: entry.systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(entry.fileName)
                .italic(tab.isPreview)
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(isActive ? .primary : .secondary)
            closeButton
        }
        .font(.callout)
        .padding(.leading, 12)
        .padding(.trailing, 6)
        .frame(minWidth: 110, maxWidth: 240, maxHeight: .infinity)
        .background(isActive ? Color(nsColor: .textBackgroundColor) : .clear)
        .overlay(alignment: .top) {
            if isActive { Color.accentColor.frame(height: 2) }
        }
        .overlay(alignment: .trailing) { Divider() }
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture(count: 2) { model.pinTab(tab.id) }
        .onTapGesture { model.activateTab(tab.id) }
        .contextMenu {
            Button("Close Tab") { model.closeTab(tab.id) }
            Button("Close Other Tabs") { model.closeOtherTabs(than: tab.id) }
                .disabled(model.tabs.count < 2)
            if tab.isPreview {
                Divider()
                Button("Keep Open") { model.pinTab(tab.id) }
            }
        }
        .help(entry.displayPath)
    }

    private var closeButton: some View {
        Button {
            model.closeTab(tab.id)
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 9, weight: .bold))
                .frame(width: 16, height: 16)
                .background(hovering ? Color.primary.opacity(0.08) : .clear, in: RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .opacity(hovering || isActive ? 1 : 0)
        .help("Close Tab (⌘W)")
    }
}
