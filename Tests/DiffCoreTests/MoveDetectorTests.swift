import Testing
@testable import DiffCore

@Suite struct MoveDetectorTests {
    private let body = [
        "func alpha() {",
        "    let value = compute(seed: 42)",
        "    print(value * 2)",
        "}",
    ]

    /// More unique lines than `body`, so the line diff keeps these in place and moves the body.
    private let stationary = (1...8).map { "stationary line number \($0) with its own text" }

    @Test func functionMovedDownIsOneMove() {
        let old = (body + [""] + stationary).joined(separator: "\n") + "\n"
        let new = (stationary + [""] + body).joined(separator: "\n") + "\n"
        let r = DiffEngine.diff(old: old, new: new)
        #expect(r.moves.count == 1)
        guard let move = r.moves.first else { return }
        #expect(move.oldLines == 0..<4)
        #expect(move.newLines == 9..<13)
        let removed = r.rows.filter { $0.kind == .removed }
        let added = r.rows.filter { $0.kind == .added }
        // The blank separator moves too but is too light to be part of the move.
        #expect(removed.count == 5 && removed.filter { $0.moveID == 0 }.count == 4)
        #expect(added.count == 5 && added.filter { $0.moveID == 0 }.count == 4)
        #expect(r.additions == 5 && r.deletions == 5, "moved lines still count")
    }

    @Test func movedLinesAreNotPairedAsModified() {
        // The block replaces alpha with a moved beta: without move detection these would pair up.
        let beta = ["func beta() {", "    return makeSomethingUseful(from: input)", "}"]
        let alpha = ["alpha line one with content", "alpha line two with content"]
        let old = (beta + stationary + alpha).joined(separator: "\n") + "\n"
        let new = (stationary + beta + ["tail line with enough characters"]).joined(separator: "\n") + "\n"
        let r = DiffEngine.diff(old: old, new: new)
        #expect(r.moves.map { ($0.oldLines, $0.newLines) }.elementsEqual([(0..<3, 8..<11)], by: { $0 == $1 }))
        // The last block removes alpha and inserts the moved beta plus one plain line; only the
        // plain line pairs with an alpha line.
        let moved = r.rows.filter(\.isMoved)
        #expect(moved.count == 6)
        #expect(moved.allSatisfy { $0.kind == .removed || $0.kind == .added })
        #expect(r.rows.filter { $0.kind == .modified }.count == 1)
    }

    @Test func trivialLinesDoNotMove() {
        let old = "}\n\n}\nfoo\n"
        let new = "foo\n}\n\n}\n"
        let r = DiffEngine.diff(old: old, new: new)
        #expect(r.moves.isEmpty)
    }

    @Test func shortContentBelowThresholdDoesNotMove() {
        let old = "let a = 1\nlet b = 2\nlong line that stays put and is not moved\n"
        let new = "long line that stays put and is not moved\nlet a = 1\nlet b = 2\n"
        let r = DiffEngine.diff(old: old, new: new)
        #expect(r.moves.isEmpty, "16 characters is below the 40-character threshold")
        var options = DiffOptions()
        options.moveMinimumCharacters = 10
        #expect(DiffEngine.diff(old: old, new: new, options: options).moves.count == 1)
    }

    @Test func detectionCanBeDisabled() {
        var options = DiffOptions()
        options.detectMoves = false
        let old = (body + [""] + stationary).joined(separator: "\n")
        let new = (stationary + [""] + body).joined(separator: "\n")
        let r = DiffEngine.diff(old: old, new: new, options: options)
        #expect(r.moves.isEmpty && !r.rows.contains { $0.isMoved })
    }

    @Test func eachInsertedLineMatchesOnce() {
        let old = (body + stationary + body).joined(separator: "\n")
        let new = (stationary + body).joined(separator: "\n")
        let r = DiffEngine.diff(old: old, new: new)
        // The second copy lines up as context; the first is a plain removal with nothing to match.
        #expect(r.moves.isEmpty)
        #expect(r.rows.filter { $0.kind == .removed }.count == 4)
        #expect(!r.rows.contains { $0.isMoved })
    }

    @Test func movedRunsAreTheirOwnChangeBlocks() {
        // The body moves past `tail`; an unrelated edit sits in the same run as each end.
        let tail = (1...8).map { "tail line number \($0) with its own text" }
        let old = stationary + body + ["old only line"] + tail
        let new = stationary + tail + ["new only line"] + body
        let r = DiffEngine.diff(old: old.joined(separator: "\n"), new: new.joined(separator: "\n"))
        guard let move = r.moves.first else { Issue.record("no move"); return }
        #expect(move.oldLines.count == body.count)
        for block in r.changeBlocks {
            #expect(Set(r.rows[block].map(\.moveID)).count == 1, "block \(block) mixes moved and unmoved rows")
            #expect(Set(r.rows[block].map(\.kind)).count == 1 || !r.rows[block.lowerBound].isMoved,
                    "block \(block) holds both ends of a move")
        }
        let movedBlocks = r.changeBlocks.filter { r.rows[$0.lowerBound].isMoved }
        #expect(movedBlocks.count == 2)
        #expect(r.changeBlocks.count == 4)   // two moved ends, "old only", "new only"
    }

    @Test func blocksSplitOnEquals() {
        let blocks = MoveDetector.blocks([.delete(old: 0), .insert(new: 0), .equal(old: 1, new: 1), .insert(new: 2), .insert(new: 3), .equal(old: 2, new: 4), .delete(old: 3)])
        #expect(blocks.map { ($0.oldLines, $0.newLines) }.elementsEqual([(0..<1, 0..<1), (2..<2, 2..<4), (3..<4, 5..<5)], by: { $0 == $1 }))
    }
}
