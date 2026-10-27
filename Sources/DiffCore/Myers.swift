/// Forward Myers O(ND) diff with a compact per-step trace.
///
/// At step `d` every `k` has the parity of `d`, so the reads `v[k±1]` only touch entries
/// written at step `d-1`, all within `|k±1| ≤ d-1`. The trace therefore stores just the
/// `-(d-1)…(d-1)` slice per step, ≈ D² Int32s in total.
///
/// The logic was validated against a brute-force LCS oracle; see `tools/myers_reference.py`.
enum Myers {
    /// Returns nil if the edit distance exceeds `maxD`.
    static func diff(_ a: ArraySlice<Int32>, _ b: ArraySlice<Int32>, maxD: Int) -> [DiffOp]? {
        let n = a.count, m = b.count, a0 = a.startIndex, b0 = b.startIndex
        if n == 0 && m == 0 { return [] }
        if n == 0 { return (0..<m).map { .insert(new: b0 + $0) } }
        if m == 0 { return (0..<n).map { .delete(old: a0 + $0) } }

        let limit = min(n + m, maxD)
        let offset = limit + 1
        var v = [Int32](repeating: 0, count: 2 * limit + 3)   // indexed by k + offset
        var trace: [[Int32]] = []                              // trace[d] = V[-(d-1)...(d-1)] at the START of step d
        var found = -1

        outer: for d in 0...limit {
            trace.append(d == 0 ? [] : Array(v[(offset - (d - 1))...(offset + (d - 1))]))
            var k = -d
            while k <= d {
                var x: Int
                if k == -d || (k != d && v[offset + k - 1] < v[offset + k + 1]) {
                    x = Int(v[offset + k + 1])          // move down (insert)
                } else {
                    x = Int(v[offset + k - 1]) + 1      // move right (delete)
                }
                var y = x - k
                while x < n && y < m && a[a0 + x] == b[b0 + y] { x += 1; y += 1 }
                v[offset + k] = Int32(x)
                if x >= n && y >= m { found = d; break outer }
                k += 2
            }
        }
        guard found >= 0 else { return nil }

        var ops: [DiffOp] = []
        var x = n, y = m, d = found
        while d > 0 {
            let vd = trace[d]                 // index k ↦ k + (d - 1)
            let k = x - y
            let prevK: Int
            if k == -d || (k != d && vd[k - 1 + d - 1] < vd[k + 1 + d - 1]) { prevK = k + 1 } else { prevK = k - 1 }
            let prevX = Int(vd[prevK + d - 1]), prevY = prevX - prevK
            while x > prevX && y > prevY { ops.append(.equal(old: a0 + x - 1, new: b0 + y - 1)); x -= 1; y -= 1 }
            if x == prevX { ops.append(.insert(new: b0 + prevY)) } else { ops.append(.delete(old: a0 + prevX)) }
            x = prevX; y = prevY; d -= 1
        }
        while x > 0 && y > 0 { ops.append(.equal(old: a0 + x - 1, new: b0 + y - 1)); x -= 1; y -= 1 }  // d == 0 snake
        ops.reverse()
        return ops
    }
}
