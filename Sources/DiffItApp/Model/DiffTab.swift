import Foundation

/// An open file in the tab bar. A preview tab (one click in the sidebar, or file navigation)
/// is reused for the next file previewed; a pinned tab (double click, Keep Open) stays until
/// it is closed. One preview tab exists at most.
struct DiffTab: Identifiable, Equatable {
    let id = UUID()
    var entryID: FileEntry.ID
    var isPreview: Bool
}
