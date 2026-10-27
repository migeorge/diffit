public enum RowKind: Equatable, Sendable {
    case context, added, removed, modified
}

/// One aligned side-by-side row. Both panes render exactly one line per row.
public struct DiffRow: Equatable, Sendable {
    public let kind: RowKind
    /// 0-based index into `DiffResult.oldLines`; nil ⇒ filler on the old side.
    public let oldLine: Int?
    /// 0-based index into `DiffResult.newLines`; nil ⇒ filler on the new side.
    public let newLine: Int?
    /// UTF-16 offset ranges within the old line (modified rows only).
    public let oldHighlights: [Range<Int>]
    /// UTF-16 offset ranges within the new line (modified rows only).
    public let newHighlights: [Range<Int>]

    public init(kind: RowKind, oldLine: Int?, newLine: Int?,
                oldHighlights: [Range<Int>] = [], newHighlights: [Range<Int>] = []) {
        self.kind = kind
        self.oldLine = oldLine
        self.newLine = newLine
        self.oldHighlights = oldHighlights
        self.newHighlights = newHighlights
    }

    func withHighlights(old: [Range<Int>], new: [Range<Int>]) -> DiffRow {
        DiffRow(kind: kind, oldLine: oldLine, newLine: newLine, oldHighlights: old, newHighlights: new)
    }
}
