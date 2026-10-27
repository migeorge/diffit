import Testing
@testable import DiffCore

@Suite struct LineSplitterTests {
    @Test func lf() {
        let r = LineSplitter.split("a\nb\nc\n")
        #expect(r.lines == ["a", "b", "c"])
        #expect(r.missingFinalNewline == false)
    }

    @Test func crlf() {
        let r = LineSplitter.split("a\r\nb\r\n")
        #expect(r.lines == ["a", "b"])
        #expect(r.missingFinalNewline == false)
    }

    @Test func mixed() {
        let r = LineSplitter.split("a\r\nb\nc\rd\n")
        #expect(r.lines == ["a", "b", "c\rd"])
    }

    @Test func noTrailingNewline() {
        let r = LineSplitter.split("a\nb")
        #expect(r.lines == ["a", "b"])
        #expect(r.missingFinalNewline == true)
    }

    @Test func empty() {
        let r = LineSplitter.split("")
        #expect(r.lines.isEmpty)
        #expect(r.missingFinalNewline == false)
    }

    @Test func onlyNewline() {
        let r = LineSplitter.split("\n")
        #expect(r.lines == [""])
        #expect(r.missingFinalNewline == false)
    }

    @Test func blankLinesPreserved() {
        let r = LineSplitter.split("a\n\n\nb\n")
        #expect(r.lines == ["a", "", "", "b"])
    }

    @Test func unicode() {
        let r = LineSplitter.split("héllo 🌍\n日本語\n")
        #expect(r.lines == ["héllo 🌍", "日本語"])
    }
}
