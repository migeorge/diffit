/// Line diff = common prefix/suffix stripping + patience anchors + Myers fallback.
struct PatienceDiff {
    private let a: [Int32]
    private let b: [Int32]
    private let myersMaxCost: Int
    private var ops: [DiffOp] = []

    /// Beyond this recursion depth, remaining gaps go straight to Myers.
    private static let maxDepth = 64

    static func diff(_ a: [Int32], _ b: [Int32], myersMaxCost: Int) -> [DiffOp] {
        var diff = PatienceDiff(a: a, b: b, myersMaxCost: myersMaxCost)
        diff.ops.reserveCapacity(max(a.count, b.count))
        diff.diffRange(0, a.count, 0, b.count, depth: 0)
        return diff.ops
    }

    private init(a: [Int32], b: [Int32], myersMaxCost: Int) {
        self.a = a
        self.b = b
        self.myersMaxCost = myersMaxCost
    }

    // MARK: - Recursion

    private mutating func diffRange(_ aLo: Int, _ aHi: Int, _ bLo: Int, _ bHi: Int, depth: Int) {
        var aLo = aLo, aHi = aHi, bLo = bLo, bHi = bHi

        // Common prefix.
        while aLo < aHi && bLo < bHi && a[aLo] == b[bLo] {
            ops.append(.equal(old: aLo, new: bLo))
            aLo += 1; bLo += 1
        }
        // Common suffix (emitted at the end).
        var suffix = 0
        while aHi - suffix > aLo && bHi - suffix > bLo && a[aHi - suffix - 1] == b[bHi - suffix - 1] {
            suffix += 1
        }
        aHi -= suffix; bHi -= suffix

        if aLo == aHi {
            for j in bLo..<bHi { ops.append(.insert(new: j)) }
        } else if bLo == bHi {
            for i in aLo..<aHi { ops.append(.delete(old: i)) }
        } else {
            let anchors = Self.anchors(a: a, b: b, aLo, aHi, bLo, bHi)
            if anchors.isEmpty || depth > Self.maxDepth {
                fallback(aLo, aHi, bLo, bHi)
            } else {
                var pa = aLo, pb = bLo
                for anchor in anchors {
                    diffRange(pa, anchor.a, pb, anchor.b, depth: depth + 1)
                    ops.append(.equal(old: anchor.a, new: anchor.b))
                    pa = anchor.a + 1; pb = anchor.b + 1
                }
                diffRange(pa, aHi, pb, bHi, depth: depth + 1)
            }
        }

        for s in 0..<suffix { ops.append(.equal(old: aHi + s, new: bHi + s)) }
    }

    /// Myers with a cost cap; when the cap is hit, emit all deletes then all inserts (coarse but correct).
    private mutating func fallback(_ aLo: Int, _ aHi: Int, _ bLo: Int, _ bHi: Int) {
        if let myers = Myers.diff(a[aLo..<aHi], b[bLo..<bHi], maxD: myersMaxCost) {
            ops.append(contentsOf: myers)
        } else {
            for i in aLo..<aHi { ops.append(.delete(old: i)) }
            for j in bLo..<bHi { ops.append(.insert(new: j)) }
        }
    }

    // MARK: - Anchors

    private struct Anchor { let a: Int; let b: Int }

    /// Lines occurring exactly once in both ranges, in a-order, reduced to the longest
    /// subsequence that is also increasing by b-index (patience sort, O(n log n)).
    private static func anchors(a: [Int32], b: [Int32], _ aLo: Int, _ aHi: Int, _ bLo: Int, _ bHi: Int) -> [Anchor] {
        // Occurrence counts scoped to the current ranges, not the whole id space.
        var countA: [Int32: Int] = [:]
        for i in aLo..<aHi { countA[a[i], default: 0] += 1 }
        var uniqueB: [Int32: Int] = [:]   // id → index in b, only for ids unique in both ranges
        var countB: [Int32: Int] = [:]
        for j in bLo..<bHi {
            let id = b[j]
            guard countA[id] == 1 else { continue }
            countB[id, default: 0] += 1
            uniqueB[id] = j
        }

        var candidates: [Anchor] = []
        for i in aLo..<aHi {
            let id = a[i]
            if countB[id] == 1, let j = uniqueB[id] { candidates.append(Anchor(a: i, b: j)) }
        }
        return longestIncreasingByB(candidates)
    }

    private static func longestIncreasingByB(_ candidates: [Anchor]) -> [Anchor] {
        guard !candidates.isEmpty else { return [] }
        var pileTops: [Int] = []                                    // candidate index on top of each pile
        var previous = [Int](repeating: -1, count: candidates.count)
        for (i, c) in candidates.enumerated() {
            var lo = 0, hi = pileTops.count
            while lo < hi {
                let mid = (lo + hi) / 2
                if candidates[pileTops[mid]].b < c.b { lo = mid + 1 } else { hi = mid }
            }
            if lo > 0 { previous[i] = pileTops[lo - 1] }
            if lo == pileTops.count { pileTops.append(i) } else { pileTops[lo] = i }
        }
        var result: [Anchor] = []
        var k = pileTops[pileTops.count - 1]
        while k >= 0 { result.append(candidates[k]); k = previous[k] }
        result.reverse()
        return result
    }
}
