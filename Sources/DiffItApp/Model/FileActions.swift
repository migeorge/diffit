import AppKit
import DiffItProtocol

/// Hand-offs to other apps for the working-tree side of a file. Nothing here writes to the file.
@MainActor
enum FileActions {
    static func revealInFinder(_ side: FileSide) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: side.path)])
    }

    static func openInDefaultEditor(_ side: FileSide) {
        NSWorkspace.shared.open(URL(fileURLWithPath: side.path))
    }
}
