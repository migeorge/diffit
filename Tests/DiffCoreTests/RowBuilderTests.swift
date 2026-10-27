import Testing
@testable import DiffCore

@Suite struct RowBuilderTests {
    @Test func contextOnly() {
        let out = RowBuilder.build([.equal(old: 0, new: 0), .equal(old: 1, new: 1)])
        #expect(out.rows.map(\.kind) == [.context, .context])
        #expect(out.changeBlocks.isEmpty)
        #expect(out.additions == 0 && out.deletions == 0)
    }

    @Test func moreDeletesThanInserts() {
        let out = RowBuilder.build([.delete(old: 0), .delete(old: 1), .delete(old: 2), .insert(new: 0), .equal(old: 3, new: 1)])
        #expect(out.rows == [
            DiffRow(kind: .modified, oldLine: 0, newLine: 0),
            DiffRow(kind: .removed, oldLine: 1, newLine: nil),
            DiffRow(kind: .removed, oldLine: 2, newLine: nil),
            DiffRow(kind: .context, oldLine: 3, newLine: 1),
        ])
        #expect(out.changeBlocks == [0..<3])
        #expect(out.deletions == 3 && out.additions == 1)
    }

    @Test func moreInsertsThanDeletes() {
        let out = RowBuilder.build([.equal(old: 0, new: 0), .delete(old: 1), .insert(new: 1), .insert(new: 2)])
        #expect(out.rows == [
            DiffRow(kind: .context, oldLine: 0, newLine: 0),
            DiffRow(kind: .modified, oldLine: 1, newLine: 1),
            DiffRow(kind: .added, oldLine: nil, newLine: 2),
        ])
        #expect(out.changeBlocks == [1..<3])
        #expect(out.deletions == 1 && out.additions == 2)
    }

    @Test func equalCounts() {
        let out = RowBuilder.build([.delete(old: 0), .delete(old: 1), .insert(new: 0), .insert(new: 1)])
        #expect(out.rows.map(\.kind) == [.modified, .modified])
        #expect(out.rows[1].oldLine == 1 && out.rows[1].newLine == 1)
    }

    /// Deletes and inserts in one run pair up regardless of their interleaving in the script.
    @Test func interleavedRunIsOneBlock() {
        let out = RowBuilder.build([.insert(new: 0), .delete(old: 0), .insert(new: 1), .delete(old: 1)])
        #expect(out.rows.map(\.kind) == [.modified, .modified])
        #expect(out.changeBlocks == [0..<2])
    }

    @Test func multipleBlocks() {
        let out = RowBuilder.build([
            .delete(old: 0), .equal(old: 1, new: 0), .equal(old: 2, new: 1), .insert(new: 2), .equal(old: 3, new: 3), .delete(old: 4),
        ])
        #expect(out.changeBlocks == [0..<1, 3..<4, 5..<6])
        #expect(out.rows.count == 6)
    }
}
