import Foundation
import Testing
@testable import DiffCore

/// Rough upper bounds, generous because tests run unoptimised (`swift test` builds debug).
/// Select with `make test FILTER=Perf`.
@Suite struct PerfTests {
    private func time(_ body: () -> Void) -> TimeInterval {
        let start = Date()
        body()
        return Date().timeIntervalSince(start)
    }

    @Test func scatteredEditsIn10kLines() {
        var lines = (0..<10_000).map { "    let value\($0) = compute(\($0 % 97), \"text \($0)\")" }
        let old = lines.joined(separator: "\n") + "\n"
        for i in stride(from: 0, to: lines.count, by: 100) { lines[i] += " // edited" }
        lines.insert(contentsOf: ["// inserted a", "// inserted b"], at: 5_000)
        lines.removeSubrange(2_000..<2_010)
        let new = lines.joined(separator: "\n") + "\n"

        var result: DiffResult?
        let elapsed = time { result = DiffEngine.diff(old: old, new: new) }
        // 100 edited + 10 removed, minus edited line 2000 which the removal swallows; 99 edited + 2 inserted.
        #expect(result?.deletions == 109)
        #expect(result?.additions == 101)
        #expect(elapsed < 1.0, "10k scattered edits took \(elapsed)s")
    }

    @Test func fullRewriteOf100kLines() {
        let old = (0..<100_000).map { "old line \($0)" }.joined(separator: "\n") + "\n"
        let new = (0..<100_000).map { "new line \($0)" }.joined(separator: "\n") + "\n"
        var result: DiffResult?
        let elapsed = time { result = DiffEngine.diff(old: old, new: new) }
        #expect(result?.rows.count == 100_000)
        #expect(result?.deletions == 100_000 && result?.additions == 100_000)
        #expect(elapsed < 5.0, "100k full rewrite took \(elapsed)s")
    }

    @Test func identical50kLines() {
        let text = (0..<50_000).map { "line \($0)" }.joined(separator: "\n") + "\n"
        var result: DiffResult?
        let elapsed = time { result = DiffEngine.diff(old: text, new: text) }
        #expect(result?.isIdentical == true)
        #expect(elapsed < 1.0, "50k identical took \(elapsed)s")
    }
}
