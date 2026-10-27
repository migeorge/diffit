/// Turns an edit script into aligned side-by-side rows.
enum RowBuilder {
    struct Output {
        var rows: [DiffRow] = []
        var changeBlocks: [Range<Int>] = []
        var additions = 0
        var deletions = 0
    }

    /// Equal → `.context`. Within each maximal run of non-equal ops, the first `min(D, I)`
    /// deletes/inserts pair up as `.modified`; the remainder become `.removed` / `.added`.
    static func build(_ ops: [DiffOp]) -> Output {
        var out = Output()
        out.rows.reserveCapacity(ops.count)
        var deletes: [Int] = []
        var inserts: [Int] = []

        func flush() {
            guard !deletes.isEmpty || !inserts.isEmpty else { return }
            let start = out.rows.count
            let paired = min(deletes.count, inserts.count)
            for i in 0..<paired {
                out.rows.append(DiffRow(kind: .modified, oldLine: deletes[i], newLine: inserts[i]))
            }
            for i in paired..<deletes.count {
                out.rows.append(DiffRow(kind: .removed, oldLine: deletes[i], newLine: nil))
            }
            for i in paired..<inserts.count {
                out.rows.append(DiffRow(kind: .added, oldLine: nil, newLine: inserts[i]))
            }
            out.changeBlocks.append(start..<out.rows.count)
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
