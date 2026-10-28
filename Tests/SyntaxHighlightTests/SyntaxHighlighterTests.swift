import Foundation
import Testing
@testable import SyntaxHighlight

@Suite struct QueryTests {
    @Test(arguments: SyntaxLanguage.allCases)
    func queryCompiles(language: SyntaxLanguage) throws {
        try SyntaxHighlighter.validate(language)
    }

    @Test(arguments: SyntaxLanguage.allCases)
    func highlightsSomething(language: SyntaxLanguage) {
        // Every grammar should colour at least one token of a tiny generic sample.
        let sample = ["# comment", "// comment", "x = \"string\" 42", "<a href=\"x\">t</a>", "SELECT 1;", "func f() {}",
                      "<?php echo 1; ?>"]
        let spans = SyntaxHighlighter.highlight(lines: sample, language: language)
        #expect(!spans.isEmpty, "\(language) produced no spans")
    }
}

@Suite struct HighlightSpanTests {
    private func kinds(_ lines: [String], _ language: SyntaxLanguage) -> [(String, TokenKind)] {
        SyntaxHighlighter.highlight(lines: lines, language: language).map { span in
            let line = lines[span.line] as NSString
            return (line.substring(with: NSRange(location: span.range.lowerBound, length: span.range.count)), span.kind)
        }
    }

    @Test func go() {
        let result = kinds(["package main", "", "// greet says hi", "func greet(name string) string {",
                            "\treturn fmt.Sprintf(\"hi %s\", name) + \"!\"", "}"], .go)
        #expect(result.contains { $0 == ("func", .keyword) })
        #expect(result.contains { $0 == ("greet", .function) })
        #expect(result.contains { $0 == ("// greet says hi", .comment) })
        #expect(result.contains { $0 == ("\"hi %s\"", .string) })
        #expect(result.contains { $0 == ("string", .type) })
    }

    @Test func swift() {
        let result = kinds(["/// Doc", "struct Point { var x: Double = 1.5 }", "let p = Point(x: 2)"], .swift)
        #expect(result.contains { $0 == ("struct", .keyword) })
        #expect(result.contains { $0 == ("Double", .type) })
        #expect(result.contains { $0 == ("1.5", .number) })
        #expect(result.contains { $0 == ("/// Doc", .comment) })
    }

    @Test func python() {
        let result = kinds(["def f(x):", "    return f'{x}'  # tail"], .python)
        #expect(result.contains { $0 == ("def", .keyword) })
        #expect(result.contains { $0 == ("f", .function) })
        #expect(result.contains { $0 == ("# tail", .comment) })
    }

    @Test func bashAndFish() {
        let bash = kinds(["if [ -f \"$x\" ]; then", "  echo done", "fi"], .bash)
        #expect(bash.contains { $0 == ("if", .keyword) })
        #expect(bash.contains { $0 == ("echo", .function) })
        let fish = kinds(["function greet", "    echo \"hi $argv\"", "end"], .fish)
        #expect(fish.contains { $0 == ("function", .keyword) })
        #expect(fish.contains { $0 == ("end", .keyword) })
    }

    @Test func markdownBlockAndInline() {
        let result = kinds(["# Title", "", "Some **bold** and `code` here.", "", "```swift", "let x = 1", "```"], .markdown)
        #expect(result.contains { $0 == ("Title", .heading) })
        #expect(result.contains { $0.1 == .strong && $0.0.contains("bold") })
        #expect(result.contains { $0.1 == .codeSpan && $0.0.contains("code") })
    }

    @Test func cFamily() {
        let c = kinds(["#include <stdio.h>", "int main(void) { return printf(\"x\\n\"); }"], .c)
        #expect(c.contains { $0 == ("int", .type) })
        #expect(c.contains { $0 == ("printf", .function) })
        #expect(c.contains { $0 == ("return", .keyword) })
        let cpp = kinds(["class Foo { public: void run() const; };", "auto x = std::make_unique<Foo>();"], .cpp)
        #expect(cpp.contains { $0 == ("class", .keyword) })
        #expect(cpp.contains { $0 == ("Foo", .type) })
    }

    @Test func rust() {
        let result = kinds(["#[derive(Debug)]", "pub fn main() -> Result<(), String> { let v: Vec<u8> = vec![1]; Ok(()) }"], .rust)
        #expect(result.contains { $0 == ("fn", .keyword) })
        #expect(result.contains { $0 == ("main", .function) })
        #expect(result.contains { $0 == ("Vec", .type) })
    }

    @Test func multiLineCommentIsSplitPerLine() {
        let spans = SyntaxHighlighter.highlight(lines: ["/* a", "b", "c */ x"], language: .c)
        let comment = spans.filter { $0.kind == .comment }
        #expect(comment.map(\.line) == [0, 1, 2])
        #expect(comment.last?.range == 0..<4)
    }

    @Test func innerCaptureOverridesOuter() {
        // The escape inside the string keeps the string colour around it.
        let spans = SyntaxHighlighter.highlight(lines: ["x := \"a\\nb\""], language: .go)
        let kinds = spans.map(\.kind)
        #expect(kinds.contains(.escape))
        #expect(kinds.filter { $0 == .string }.count == 2)
    }

    @Test func emptyAndHugeInputs() {
        #expect(SyntaxHighlighter.highlight(lines: [], language: .go).isEmpty)
        #expect(SyntaxHighlighter.highlight(lines: [""], language: .go).isEmpty)
        let huge = [String](repeating: String(repeating: "x", count: 1000), count: SyntaxHighlighter.characterLimit / 1000 + 1)
        #expect(SyntaxHighlighter.highlight(lines: huge, language: .go).isEmpty)
    }
}

@Suite struct DetectionTests {
    @Test func byExtensionAndName() {
        #expect(SyntaxLanguage.detect(path: "/a/b/main.go") == .go)
        #expect(SyntaxLanguage.detect(path: "Sources/App/File.swift") == .swift)
        #expect(SyntaxLanguage.detect(path: "x/Dockerfile") == .dockerfile)
        #expect(SyntaxLanguage.detect(path: "web.dockerfile") == .dockerfile)
        #expect(SyntaxLanguage.detect(path: "Gemfile") == .ruby)
        #expect(SyntaxLanguage.detect(path: "README.MD") == .markdown)
        #expect(SyntaxLanguage.detect(path: "view.tsx") == .tsx)
        #expect(SyntaxLanguage.detect(path: "Info.plist") == .xml)
        #expect(SyntaxLanguage.detect(path: "notes.txt") == nil)
        #expect(SyntaxLanguage.detect(path: "Makefile") == nil)
    }

    @Test func byShebang() {
        #expect(SyntaxLanguage.detect(path: "bin/run", firstLine: "#!/bin/bash") == .bash)
        #expect(SyntaxLanguage.detect(path: "bin/run", firstLine: "#!/usr/bin/env python3") == .python)
        #expect(SyntaxLanguage.detect(path: "bin/run", firstLine: "#!/usr/local/bin/fish") == .fish)
        #expect(SyntaxLanguage.detect(path: "bin/run", firstLine: "#!/usr/bin/env -S node --harmony") == nil)
        #expect(SyntaxLanguage.detect(path: "bin/run", firstLine: "plain text") == nil)
        // The extension wins over a shebang.
        #expect(SyntaxLanguage.detect(path: "tool.py", firstLine: "#!/bin/sh") == .python)
    }
}
