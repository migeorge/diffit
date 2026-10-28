import Foundation

/// Public entry point of the diff engine.
public enum DiffEngine {
    public static func diff(old: String, new: String, options: DiffOptions = .init()) -> DiffResult {
        let oldSplit = LineSplitter.split(old)
        let newSplit = LineSplitter.split(new)

        var interner = Interner<String>()
        let a = interner.intern(oldSplit.lines)
        let b = interner.intern(newSplit.lines)
        let ops = PatienceDiff.diff(a, b, myersMaxCost: options.myersMaxCost)

        var built = RowBuilder.build(ops)
        if options.intraLine {
            for (index, row) in built.rows.enumerated() {
                guard row.kind == .modified, let o = row.oldLine, let n = row.newLine else { continue }
                let h = IntraLineDiff.highlights(old: oldSplit.lines[o], new: newSplit.lines[n], options: options)
                if !h.old.isEmpty || !h.new.isEmpty {
                    built.rows[index] = row.withHighlights(old: h.old, new: h.new)
                }
            }
        }

        return DiffResult(
            oldLines: oldSplit.lines,
            newLines: newSplit.lines,
            rows: built.rows,
            changeBlocks: built.changeBlocks,
            additions: built.additions,
            deletions: built.deletions,
            oldMissingFinalNewline: oldSplit.missingFinalNewline,
            newMissingFinalNewline: newSplit.missingFinalNewline
        )
    }

    /// For each line of `from`, the index of the same line in `to`, or -1 when it has no
    /// counterpart. Used to keep a viewport on the same content when a file is reloaded.
    public static func lineMapping(from: [String], to: [String], options: DiffOptions = .init()) -> [Int] {
        var interner = Interner<String>()
        let a = interner.intern(from), b = interner.intern(to)
        var mapping = [Int](repeating: -1, count: from.count)
        for case .equal(let old, let new) in PatienceDiff.diff(a, b, myersMaxCost: options.myersMaxCost) {
            mapping[old] = new
        }
        return mapping
    }

    /// Line-level edit script over interned ids. Exposed for tests.
    public static func diffLines(_ old: [Int32], _ new: [Int32], options: DiffOptions = .init()) -> [DiffOp] {
        PatienceDiff.diff(old, new, myersMaxCost: options.myersMaxCost)
    }

    /// A NUL byte within the first 8 KiB marks the data as binary.
    public static func isProbablyBinary(_ data: Data) -> Bool {
        data.prefix(8192).contains(0)
    }
}
