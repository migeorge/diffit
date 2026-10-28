public struct DiffResult: Sendable {
    public let oldLines: [String]
    public let newLines: [String]
    public let rows: [DiffRow]
    /// Maximal runs of non-context rows (row-index ranges), for navigation.
    public let changeBlocks: [Range<Int>]
    public let additions: Int
    public let deletions: Int
    /// Blocks removed in one place and inserted unchanged in another (still counted above).
    public let moves: [DiffMove]
    public let oldMissingFinalNewline: Bool
    public let newMissingFinalNewline: Bool

    public init(oldLines: [String], newLines: [String], rows: [DiffRow], changeBlocks: [Range<Int>],
                additions: Int, deletions: Int, moves: [DiffMove] = [],
                oldMissingFinalNewline: Bool, newMissingFinalNewline: Bool) {
        self.oldLines = oldLines
        self.newLines = newLines
        self.rows = rows
        self.changeBlocks = changeBlocks
        self.additions = additions
        self.deletions = deletions
        self.moves = moves
        self.oldMissingFinalNewline = oldMissingFinalNewline
        self.newMissingFinalNewline = newMissingFinalNewline
    }

    /// True when the two inputs produced no added, removed or modified rows.
    public var isIdentical: Bool { changeBlocks.isEmpty }
}
