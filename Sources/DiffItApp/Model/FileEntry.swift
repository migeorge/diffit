import Foundation
import DiffCore
import SyntaxHighlight
import DiffItProtocol

enum FileStatus {
    case modified, added, deleted, binary, unreadable
}

@MainActor @Observable
final class FileEntry: Identifiable {
    let id = UUID()
    let displayPath: String
    let old: FileSide?
    let new: FileSide?

    var status: FileStatus
    var result: DiffResult?
    var isLoading = false
    var error: String?
    /// Bumps on every reload; views use it to know content changed.
    var generation = 0
    /// Set when a side was too large for intra-line highlighting.
    var intraLineDisabled = false
    /// Byte sizes of each side, shown for binary files.
    var oldSize: Int?
    var newSize: Int?

    /// Loader bookkeeping: a reload arrived while one was running.
    var reloadRequested = false
    /// For the latest reload: each new-side line index of the previous generation → its index
    /// now, or -1. Lets the panes keep the same content in view.
    @ObservationIgnored var newLineMapping: [Int]?
    /// Syntax colours per side, computed with the diff; empty when the language is unknown.
    @ObservationIgnored var oldSyntax: [HighlightSpan] = []
    @ObservationIgnored var newSyntax: [HighlightSpan] = []

    /// Watchers for the live sides; empty until `AppModel` starts them.
    @ObservationIgnored var watchers: [FileWatcher] = []
    var isWatched: Bool { !watchers.isEmpty }

    init(displayPath: String, old: FileSide?, new: FileSide?) {
        self.displayPath = displayPath
        self.old = old
        self.new = new
        switch (old, new) {
        case (nil, _): status = .added
        case (_, nil): status = .deleted
        default: status = .modified
        }
    }

    var fileName: String { (displayPath as NSString).lastPathComponent }

    /// SF Symbol for the status (sidebar rows and tabs).
    var systemImage: String {
        switch status {
        case .added: "doc.badge.plus"
        case .deleted: "trash"   // there is no doc.badge.minus symbol
        case .modified: "doc.text"
        case .binary: "doc.zipper"
        case .unreadable: "doc.questionmark"
        }
    }
    var liveSides: [FileSide] { [old, new].compactMap { $0 }.filter(\.isLive) }
    var additions: Int { result?.additions ?? 0 }
    var deletions: Int { result?.deletions ?? 0 }

    /// The side that lives in the working tree, if any (for Reveal in Finder etc.).
    var liveSide: FileSide? {
        if let new, new.isLive { return new }
        if let old, old.isLive { return old }
        return nil
    }
}
