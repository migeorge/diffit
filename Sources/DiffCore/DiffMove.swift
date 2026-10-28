/// A block of lines that was removed in one place and inserted, unchanged, in another.
/// Rows carrying `moveID == id` on the old side are the source, on the new side the destination.
public struct DiffMove: Equatable, Sendable {
    public let id: Int
    /// Indices into `DiffResult.oldLines`.
    public let oldLines: Range<Int>
    /// Indices into `DiffResult.newLines`.
    public let newLines: Range<Int>

    public init(id: Int, oldLines: Range<Int>, newLines: Range<Int>) {
        self.id = id
        self.oldLines = oldLines
        self.newLines = newLines
    }
}
