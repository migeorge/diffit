import AppKit
import DiffCore

/// Everything one pane needs to render one side of a diff: the attributed text plus
/// per-line metadata the text view and gutter look up while drawing.
/// One line per `DiffRow`; both sides of a pair have the same `lineCount`.
struct DiffPaneContent {
    let side: DiffSide
    let text: NSAttributedString
    /// UTF-16 offset of the start of each line.
    let lineStarts: [Int]
    let rowKinds: [RowKind]
    /// True where this side has no line for the row.
    let isFiller: [Bool]
    /// 1-based source line number for the gutter; nil for fillers.
    let sourceLineNumbers: [Int?]
    /// Row indices where each change block starts (for navigation).
    let changeBlocks: [Range<Int>]
    /// Height of every row; the paragraph style pins each line to it.
    let lineHeight: CGFloat

    var lineCount: Int { lineStarts.count }

    /// The line containing a UTF-16 offset (largest `i` with `lineStarts[i] <= offset`).
    func lineIndex(forUTF16Offset offset: Int) -> Int? {
        guard !lineStarts.isEmpty, offset >= 0 else { return nil }
        var low = 0, high = lineStarts.count - 1
        while low < high {
            let mid = (low + high + 1) / 2
            if lineStarts[mid] <= offset { low = mid } else { high = mid - 1 }
        }
        return low
    }

    func rowBackground(_ line: Int) -> NSColor? {
        guard rowKinds.indices.contains(line) else { return nil }
        return Theme.rowBackground(rowKinds[line], side: side, isFiller: isFiller[line])
    }

    func gutterBackground(_ line: Int) -> NSColor? {
        guard rowKinds.indices.contains(line) else { return nil }
        return Theme.gutterRowBackground(rowKinds[line], side: side, isFiller: isFiller[line])
    }

    /// Largest source line number, for sizing the gutter.
    var maxSourceLineNumber: Int {
        sourceLineNumbers.lazy.compactMap { $0 }.max() ?? 0
    }

    static func empty(side: DiffSide) -> DiffPaneContent {
        DiffPaneContent(side: side, text: NSAttributedString(), lineStarts: [], rowKinds: [],
                        isFiller: [], sourceLineNumbers: [], changeBlocks: [], lineHeight: 1)
    }
}
