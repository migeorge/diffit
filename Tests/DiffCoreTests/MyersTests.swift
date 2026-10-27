import Testing
@testable import DiffCore

@Suite struct MyersTests {
    private func myers(_ a: String, _ b: String, maxD: Int = 1_000_000) -> [DiffOp]? {
        Myers.diff(ids(a)[...], ids(b)[...], maxD: maxD)
    }

    private func check(_ a: String, _ b: String, cost: Int) {
        let ops = myers(a, b)
        #expect(ops != nil)
        guard let ops else { return }
        #expect(apply(ops, old: ids(a), new: ids(b)) == ids(b), "\(a) → \(b): \(ops)")
        #expect(editCost(ops) == cost, "\(a) → \(b): \(ops)")
    }

    @Test func identical() { check("abc", "abc", cost: 0) }
    @Test func bothEmpty() { check("", "", cost: 0) }
    @Test func emptyVsNonEmpty() { check("", "abc", cost: 3); check("abc", "", cost: 3) }
    @Test func allDifferent() { check("abc", "xyz", cost: 6) }
    @Test func insertAtStart() { check("bc", "abc", cost: 1) }
    @Test func insertInMiddle() { check("ac", "abc", cost: 1) }
    @Test func insertAtEnd() { check("ab", "abc", cost: 1) }
    @Test func deleteAtStart() { check("abc", "bc", cost: 1) }
    @Test func deleteInMiddle() { check("abc", "ac", cost: 1) }
    @Test func deleteAtEnd() { check("abc", "ab", cost: 1) }
    @Test func interleaved() { check("abcabc", "acbacb", cost: 4) }
    @Test func classic() { check("ABCABBA", "CBABAC", cost: 5) }

    @Test func costCap() {
        #expect(myers("abcdef", "uvwxyz", maxD: 3) == nil)
        #expect(myers("abcdef", "abcxef", maxD: 2) != nil)
    }

    @Test func sliceOffsetsArePreserved() {
        let a: [Int32] = [9, 9, 1, 2, 3], b: [Int32] = [8, 1, 5, 3]
        let ops = Myers.diff(a[2...], b[1...], maxD: 100)
        #expect(ops == [.equal(old: 2, new: 1), .delete(old: 3), .insert(new: 2), .equal(old: 4, new: 3)])
    }

    /// Random sequences over a 3-symbol alphabet: the script must reproduce `new`
    /// and its cost must equal the brute-force edit distance.
    @Test func propertyMinimalAndConsistent() {
        var rng = SeededGenerator(seed: 1)
        for _ in 0..<5_000 {
            let n = Int.random(in: 0...12, using: &rng), m = Int.random(in: 0...12, using: &rng)
            let a = (0..<n).map { _ in Int32.random(in: 0..<3, using: &rng) }
            let b = (0..<m).map { _ in Int32.random(in: 0..<3, using: &rng) }
            guard let ops = Myers.diff(a[...], b[...], maxD: 1_000_000) else {
                Issue.record("nil for \(a) → \(b)"); return
            }
            #expect(apply(ops, old: a, new: b) == b, "\(a) → \(b): \(ops)")
            #expect(editCost(ops) == n + m - 2 * lcsLength(a, b), "\(a) → \(b): \(ops)")
        }
    }
}
