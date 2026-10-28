import SwiftUI
import DiffCore

/// Hosts `DiffPairView` in SwiftUI. Inputs are plain values so SwiftUI tracks them; the panes are
/// rebuilt only when the entry, its generation, or the text settings change.
struct DiffPairRepresentable: NSViewRepresentable {
    let entryID: FileEntry.ID
    let generation: Int
    let result: DiffResult?
    /// Centred label for a side with no file at all ("No original", "Deleted").
    let oldPlaceholder: String?
    let newPlaceholder: String?
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
        AppModel.shared.activeNavigator = view
        return view
    }

    func updateNSView(_ view: DiffPairView, context: Context) {
        let key = Key(entryID: entryID, generation: generation, settingsVersion: settingsVersion)
        guard context.coordinator.lastKey != key else { return }
        let sameEntry = context.coordinator.lastKey?.entryID == entryID
        context.coordinator.lastKey = key
        let style = DiffTextBuilder.Style(font: font, tabWidth: tabWidth, intraLineHighlights: intraLineHighlights)
        view.setPlaceholders(old: oldPlaceholder, new: newPlaceholder)
        view.load(result, style: style, showChangeHatch: showChangeHatch, keepScroll: sameEntry)
        if AppModel.shared.activeNavigator == nil { AppModel.shared.activeNavigator = view }
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
