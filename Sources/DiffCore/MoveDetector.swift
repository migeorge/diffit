/// Finds blocks of deleted lines that reappear verbatim among the inserted lines elsewhere.
///
/// Works on the edit script: every maximal run of non-equal ops is a block with a contiguous
/// range of deleted old lines and inserted new lines. For each deleted line that is not yet
/// part of a move, the longest run of inserted lines with identical content is taken (greedy,
/// left to right); a match counts only if it is substantial enough (see `DiffOptions`), so
/// stray braces and blank lines do not pair up across the file.
enum MoveDetector {
    struct Block {
        var oldLines: Range<Int>
        var newLines: Range<Int>
    }

    static func detect(ops: [DiffOp], oldIDs: [Int32], newIDs: [Int32], oldLines: [String],
                       options: DiffOptions) -> [DiffMove] {
        let blocks = Self.blocks(ops)
        guard blocks.count > 1 || blocks.contains(where: { !$0.oldLines.isEmpty && !$0.newLines.isEmpty }) else {
            return []
        }

        var isInserted = [Bool](repeating: false, count: newIDs.count)
        var candidates: [Int32: [Int]] = [:]
        for block in blocks {
            for n in block.newLines {
                isInserted[n] = true
                candidates[newIDs[n], default: []].append(n)
            }
        }
        guard !candidates.isEmpty else { return [] }

        let weights = oldLines.map(weight)
        var usedNew = [Bool](repeating: false, count: newIDs.count)
        var moves: [DiffMove] = []

        for block in blocks {
            var i = block.oldLines.lowerBound
            while i < block.oldLines.upperBound {
                // Only a line with some substance may start a match.
                guard weights[i] >= options.moveMinimumLineCharacters,
                      let starts = candidates[oldIDs[i]] else { i += 1; continue }
                var best: (start: Int, length: Int)?
                for start in starts.prefix(Self.maxCandidates) where !usedNew[start] {
                    var length = 0
                    while i + length < block.oldLines.upperBound,
                          start + length < newIDs.count,
                          isInserted[start + length], !usedNew[start + length],
                          oldIDs[i + length] == newIDs[start + length] {
                        length += 1
                    }
                    if length > (best?.length ?? 0) { best = (start, length) }
                }
                guard let best else { i += 1; continue }
                let length = best.length
                let total = (i..<(i + length)).reduce(0) { $0 + weights[$1] }
                guard total >= options.moveMinimumCharacters else { i += 1; continue }
                for n in best.start..<(best.start + length) { usedNew[n] = true }
                moves.append(DiffMove(id: moves.count, oldLines: i..<(i + length), newLines: best.start..<(best.start + length)))
                i += length
            }
        }
        return moves
    }

    /// Lines whose content is this common are too ambiguous to search exhaustively.
    private static let maxCandidates = 64

    /// Non-whitespace character count.
    static func weight(_ line: String) -> Int {
        var count = 0
        for scalar in line.unicodeScalars where !scalar.properties.isWhitespace { count += 1 }
        return count
    }

    /// Contiguous deleted / inserted ranges of every maximal run of non-equal ops.
    static func blocks(_ ops: [DiffOp]) -> [Block] {
        var blocks: [Block] = []
        var oldLo: Int?, oldHi = 0, newLo: Int?, newHi = 0
        func flush() {
            if oldLo != nil || newLo != nil {
                blocks.append(Block(oldLines: (oldLo ?? oldHi)..<oldHi, newLines: (newLo ?? newHi)..<newHi))
            }
            oldLo = nil; newLo = nil
        }
        for op in ops {
            switch op {
            case .equal(let old, let new):
                flush()
                oldHi = old + 1; newHi = new + 1
            case .delete(let old):
                if oldLo == nil { oldLo = old }
                oldHi = old + 1
            case .insert(let new):
                if newLo == nil { newLo = new }
                newHi = new + 1
            }
        }
        flush()
        return blocks
    }
}
