import SwiftUI
import DiffCore
import SyntaxHighlight

/// Hosts `DiffPairView` in SwiftUI. Inputs are plain values so SwiftUI tracks them; the panes are
/// rebuilt only when the entry, its generation, or the text settings change.
struct DiffPairRepresentable: NSViewRepresentable {
    let entryID: FileEntry.ID
    let generation: Int
    let result: DiffResult?
    /// Previous generation's new-side lines → current (see `FileEntry.newLineMapping`).
    let lineMapping: [Int]?
    let oldSyntax: [HighlightSpan]
    let newSyntax: [HighlightSpan]
    /// Centred label for a side with no file at all ("No original", "Deleted").
    let oldPlaceholder: String?
    let newPlaceholder: String?
    let oldHeader: PaneHeaderView.Content
    let newHeader: PaneHeaderView.Content
    let isActive: Bool
    let font: NSFont
    let tabWidth: Int
    let intraLineHighlights: Bool
    let showChangeHatch: Bool
    let settingsVersion: Int

    struct Key: Equatable {
        var entryID: FileEntry.ID
        var generation: Int
        var settingsVersion: Int
    }

    func makeNSView(context: Context) -> DiffPairView {
        let view = DiffPairView(frame: .zero)
        context.coordinator.view = view
        view.onNavigationChange = { state in AppModel.shared.changeNavigation = state }
        return view
    }

    func updateNSView(_ view: DiffPairView, context: Context) {
        view.setHeaders(old: oldHeader, new: newHeader)
        updateActivation(view)
        let key = Key(entryID: entryID, generation: generation, settingsVersion: settingsVersion)
        guard context.coordinator.lastKey != key else { return }
        let sameEntry = context.coordinator.lastKey?.entryID == entryID
        let contentChanged = context.coordinator.lastKey?.generation != generation
        context.coordinator.lastKey = key
        let style = DiffTextBuilder.Style(font: font, tabWidth: tabWidth, intraLineHighlights: intraLineHighlights)
        view.setPlaceholders(old: oldPlaceholder, new: newPlaceholder)
        view.load(result, style: style, showChangeHatch: showChangeHatch, keepScroll: sameEntry,
                  lineMapping: sameEntry && contentChanged ? lineMapping : nil,
                  oldSyntax: oldSyntax, newSyntax: newSyntax)
    }

    /// The visible tab's pair view is the navigator; a tab going hidden gives it up only if it
    /// still holds it (the new tab may already have taken over, in either order).
    private func updateActivation(_ view: DiffPairView) {
        let model = AppModel.shared
        if isActive {
            if model.activeNavigator !== view { model.activeNavigator = view }
            view.setActive(true)
        } else if view.isActive {
            view.setActive(false)
            if model.activeNavigator === view {
                model.activeNavigator = nil
                model.changeNavigation = .none
            }
        }
    }

    static func dismantleNSView(_ view: DiffPairView, coordinator: Coordinator) {
        if AppModel.shared.activeNavigator === view {
            AppModel.shared.activeNavigator = nil
            AppModel.shared.changeNavigation = .none
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    @MainActor
    final class Coordinator {
        var lastKey: Key?
        weak var view: DiffPairView?
    }
}
