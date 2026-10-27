import Foundation
import Testing
@testable import DiffCore

@Suite struct DiffEngineTests {
    @Test func endToEnd() {
        let old = "a\nb\nc\nd\n", new = "a\nB\nc\nd\ne\n"
        let r = DiffEngine.diff(old: old, new: new)
        #expect(r.oldLines == ["a", "b", "c", "d"])
        #expect(r.newLines == ["a", "B", "c", "d", "e"])
        #expect(r.rows.map(\.kind) == [.context, .modified, .context, .context, .added])
        #expect(r.changeBlocks == [1..<2, 4..<5])
        #expect(r.additions == 2 && r.deletions == 1)
        #expect(!r.oldMissingFinalNewline && !r.newMissingFinalNewline)
        #expect(!r.isIdentical)
    }

    @Test func identical() {
        let r = DiffEngine.diff(old: "x\ny\n", new: "x\ny\n")
        #expect(r.isIdentical)
        #expect(r.rows.map(\.kind) == [.context, .context])
    }

    @Test func missingFinalNewlineFlags() {
        let r = DiffEngine.diff(old: "x", new: "x\n")
        #expect(r.oldMissingFinalNewline && !r.newMissingFinalNewline)
        #expect(r.isIdentical, "newline-at-EOF difference is reported via flags, not as a changed row")
    }

    @Test func intraLineHighlightsAttached() {
        let r = DiffEngine.diff(old: "let a = 1\n", new: "let b = 1\n")
        #expect(r.rows[0].kind == .modified)
        #expect(r.rows[0].oldHighlights == [4..<5])
        #expect(r.rows[0].newHighlights == [4..<5])
    }

    @Test func intraLineCanBeDisabled() {
        var options = DiffOptions()
        options.intraLine = false
        let r = DiffEngine.diff(old: "let a = 1\n", new: "let b = 1\n", options: options)
        #expect(r.rows[0].oldHighlights.isEmpty && r.rows[0].newHighlights.isEmpty)
    }

    @Test func addedAndDeletedFiles() {
        let added = DiffEngine.diff(old: "", new: "a\nb\n")
        #expect(added.rows.map(\.kind) == [.added, .added])
        #expect(added.rows.allSatisfy { $0.oldLine == nil })
        let deleted = DiffEngine.diff(old: "a\nb\n", new: "")
        #expect(deleted.rows.map(\.kind) == [.removed, .removed])
        #expect(deleted.rows.allSatisfy { $0.newLine == nil })
    }

    @Test func binaryDetection() {
        #expect(DiffEngine.isProbablyBinary(Data([0x41, 0x42, 0x00, 0x43])))
        #expect(!DiffEngine.isProbablyBinary(Data("plain text\n".utf8)))
        #expect(!DiffEngine.isProbablyBinary(Data()))
        var late = Data(repeating: 0x41, count: 8192)
        late.append(0)
        #expect(!DiffEngine.isProbablyBinary(late), "only the first 8 KiB is inspected")
    }
}
