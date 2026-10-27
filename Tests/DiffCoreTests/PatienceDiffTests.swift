import Testing
@testable import DiffCore

@Suite struct PatienceDiffTests {
    private func diff(_ a: [String], _ b: [String], maxCost: Int = 2_000) -> [DiffOp] {
        var interner = Interner<String>()
        let x = interner.intern(a), y = interner.intern(b)
        let ops = PatienceDiff.diff(x, y, myersMaxCost: maxCost)
        #expect(apply(ops, old: x, new: y) == y, "\(a) → \(b): \(ops)")
        return ops
    }

    @Test func identical() {
        let ops = diff(["a", "b", "c"], ["a", "b", "c"])
        #expect(editCost(ops) == 0)
    }

    @Test func emptySides() {
        #expect(diff([], ["a", "b"]) == [.insert(new: 0), .insert(new: 1)])
        #expect(diff(["a", "b"], []) == [.delete(old: 0), .delete(old: 1)])
        #expect(diff([], []) == [])
    }

    /// Unique lines anchor the diff so a moved block is reported as one delete + one insert run,
    /// rather than Myers' tendency to interleave.
    @Test func movedBlock() {
        let a = ["int x;", "int y;", "", "void f() {", "  body1", "  body2", "}", "", "void g() {", "  g1", "}"]
        let b = ["int x;", "int y;", "", "void g() {", "  g1", "}", "", "void f() {", "  body1", "  body2", "}"]
        let ops = diff(a, b)
        // Cost is the moved block's size in each direction; anchors keep the larger block in place.
        #expect(editCost(ops) <= 8)
    }

    @Test func duplicatedLinesFallBackToMyers() {
        // Nothing is unique on both sides, so anchors are empty and Myers handles it.
        let a = ["x", "x", "y", "x", "x"], b = ["x", "y", "x", "x", "x"]
        let ops = diff(a, b)
        #expect(editCost(ops) == 2)
    }

    @Test func singleLineChangeInLargeFile() {
        let a = (0..<500).map { "line \($0)" }
        var b = a
        b[250] = "changed"
        let ops = diff(a, b)
        #expect(editCost(ops) == 2)
        #expect(ops.contains(.delete(old: 250)))
        #expect(ops.contains(.insert(new: 250)))
    }

    @Test func costCapStillReproducesNew() {
        let a = (0..<300).map { "a\($0)" }, b = (0..<300).map { "b\($0)" }
        let ops = diff(a, b, maxCost: 5)
        #expect(editCost(ops) == 600)
        let firstInsert = ops.firstIndex { if case .insert = $0 { return true } else { return false } }
        #expect(firstInsert == 300, "coarse fallback emits all deletes before all inserts")
    }

    @Test func deepRecursionGuard() {
        // Each level peels one unique anchor off; depth guard must not break correctness.
        let a = (0..<200).map { "u\($0)" }
        let b = (0..<200).flatMap { ["u\($0)", "dup"] }
        _ = diff(a, b)
        _ = diff(b, a)
    }

    /// Random sequences over a small alphabet (so duplicates are common): every script must replay to `new`.
    @Test func propertyReproducesNew() {
        var rng = SeededGenerator(seed: 7)
        for _ in 0..<2_000 {
            let n = Int.random(in: 0...40, using: &rng), m = Int.random(in: 0...40, using: &rng)
            let alphabet = Int32.random(in: 2...12, using: &rng)
            let a = (0..<n).map { _ in Int32.random(in: 0..<alphabet, using: &rng) }
            let b = (0..<m).map { _ in Int32.random(in: 0..<alphabet, using: &rng) }
            let cap = Bool.random(using: &rng) ? 2_000 : Int.random(in: 0...6, using: &rng)
            let ops = PatienceDiff.diff(a, b, myersMaxCost: cap)
            #expect(apply(ops, old: a, new: b) == b, "\(a) → \(b) cap \(cap): \(ops)")
        }
    }
}
