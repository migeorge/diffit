/// Turns an edit script into aligned side-by-side rows.
enum RowBuilder {
    struct Output {
        var rows: [DiffRow] = []
        var changeBlocks: [Range<Int>] = []
        var additions = 0
        var deletions = 0
    }

    /// Equal → `.context`. Within each maximal run of non-equal ops, deletes and inserts that
    /// are not part of a move pair up as `.modified` (first `min(D, I)` of each); the remainder,
    /// and every moved line, become `.removed` / `.added` rows, moved ones tagged with their move.
    /// A run yields one change block per stretch of rows sharing a move id (nil included).
    /// A block boundary falls where the move id changes, and between the two ends of a move
    /// that happen to sit in the same run (a local reorder) so each end is navigable.
    private static func startsBlock(_ row: DiffRow, after previous: DiffRow) -> Bool {
        row.moveID != previous.moveID || (row.moveID != nil && row.kind != previous.kind)
    }

    static func build(_ ops: [DiffOp], moves: [DiffMove] = []) -> Output {
        var out = Output()
        out.rows.reserveCapacity(ops.count)
        var deletes: [Int] = []
        var inserts: [Int] = []
        var movedOld: [Int: Int] = [:], movedNew: [Int: Int] = [:]
        for move in moves {
            for line in move.oldLines { movedOld[line] = move.id }
            for line in move.newLines { movedNew[line] = move.id }
        }

        func flush() {
            guard !deletes.isEmpty || !inserts.isEmpty else { return }
            let start = out.rows.count
            let plainDeletes = deletes.filter { movedOld[$0] == nil }
            let plainInserts = inserts.filter { movedNew[$0] == nil }
            let paired = min(plainDeletes.count, plainInserts.count)
            for i in 0..<paired {
                out.rows.append(DiffRow(kind: .modified, oldLine: plainDeletes[i], newLine: plainInserts[i]))
            }
            let pairedDeletes = Set(plainDeletes.prefix(paired)), pairedInserts = Set(plainInserts.prefix(paired))
            for line in deletes where !pairedDeletes.contains(line) {
                out.rows.append(DiffRow(kind: .removed, oldLine: line, newLine: nil, moveID: movedOld[line]))
            }
            for line in inserts where !pairedInserts.contains(line) {
                out.rows.append(DiffRow(kind: .added, oldLine: nil, newLine: line, moveID: movedNew[line]))
            }
            // Each moved run is its own block so navigation and the marker strip treat it as a move.
            var blockStart = start
            for i in (start + 1)..<out.rows.count where Self.startsBlock(out.rows[i], after: out.rows[i - 1]) {
                out.changeBlocks.append(blockStart..<i)
                blockStart = i
            }
            out.changeBlocks.append(blockStart..<out.rows.count)
            out.deletions += deletes.count
            out.additions += inserts.count
            deletes.removeAll(keepingCapacity: true)
            inserts.removeAll(keepingCapacity: true)
        }

        for op in ops {
            switch op {
            case .equal(let old, let new):
                flush()
                out.rows.append(DiffRow(kind: .context, oldLine: old, newLine: new))
            case .delete(let old):
                deletes.append(old)
            case .insert(let new):
                inserts.append(new)
            }
        }
        flush()
        return out
    }
}
