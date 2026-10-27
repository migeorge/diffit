import Testing
@testable import DiffCore

@Suite struct IntraLineDiffTests {
    private func highlights(_ old: String, _ new: String, options: DiffOptions = .init()) -> IntraLineDiff.Highlights {
        IntraLineDiff.highlights(old: old, new: new, options: options)
    }

    private func utf16Range(of needle: String, in s: String) -> Range<Int>? {
        guard let r = s.range(of: needle) else { return nil }
        let u = s.utf16
        return u.distance(from: u.startIndex, to: r.lowerBound)..<u.distance(from: u.startIndex, to: r.upperBound)
    }

    @Test func singleWordChange() {
        let old = "let count = items.count", new = "let total = items.count"
        let h = highlights(old, new)
        #expect(h.old == [utf16Range(of: "count", in: old)].compactMap { $0 })
        #expect(h.new == [utf16Range(of: "total", in: new)].compactMap { $0 })
    }

    @Test func whitespaceOnlyChange() {
        let old = "a = b", new = "a  =  b"
        let h = highlights(old, new)
        #expect(h.old == [1..<2, 3..<4])
        #expect(h.new == [1..<3, 4..<6])
    }

    @Test func adjacentTokensMerge() {
        let old = "foo(x)", new = "foo(x, y)"
        let h = highlights(old, new)
        #expect(h.old.isEmpty)
        #expect(h.new == [5..<8])   // ", y" as one range
    }

    @Test func thresholdDropsHighlights() {
        let h = highlights("alpha beta gamma", "one two three four")
        #expect(h == IntraLineDiff.Highlights())
    }

    @Test func thresholdIsConfigurable() {
        var options = DiffOptions()
        options.intraLineMaxChangedFraction = 1.0
        let h = highlights("alpha beta gamma", "one two three four", options: options)
        #expect(!h.old.isEmpty && !h.new.isEmpty)
    }

    @Test func tooLongLinesAreSkipped() {
        var options = DiffOptions()
        options.intraLineMaxLineLength = 10
        let h = highlights("short line here", "short lines here", options: options)
        #expect(h == IntraLineDiff.Highlights())
    }

    @Test func utf16OffsetsWithEmojiAndCJK() {
        // 🌍 is two UTF-16 units; 日本 are two single units.
        let old = "x = \"🌍 日本 ok\"", new = "x = \"🌍 日本 no\""
        let h = highlights(old, new)
        #expect(h.old == [utf16Range(of: "ok", in: old)].compactMap { $0 })
        #expect(h.new == [utf16Range(of: "no", in: new)].compactMap { $0 })
        #expect(h.old == [11..<13])
    }

    @Test func tokenizerClasses() {
        let t = Tokenizer.tokenize(Array("ab_1 += (x)".utf16)).map(\.range)
        #expect(t == [0..<4, 4..<5, 5..<6, 6..<7, 7..<8, 8..<9, 9..<10, 10..<11])
    }
}
