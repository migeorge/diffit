import Foundation
import os
import SwiftTreeSitter

/// Runs a grammar's highlight query over a file and reports coloured runs per line.
///
/// Precedence: a capture on an inner node overrides the colour of the node around it, and when
/// several patterns capture the same node the last *coloured* one wins. (tree-sitter's own
/// highlighter lets the last pattern win outright, but the bundled queries were written under
/// both that rule and the older first-wins rule, so a plain `(identifier) @variable` sits first
/// in some files and last in others; ignoring plain captures in the tie-break serves both.)
/// Captures that map to no colour leave the surrounding colour in place.
public enum SyntaxHighlighter {
    /// Sides longer than this (UTF-16 units, about 25k lines of code) are not highlighted. Parsing
    /// is cheap, but every coloured run slows the text view's one-shot layout: a 55k-line Go file
    /// takes about 1 s to lay out with colours against 0.3 s without, so very large files stay plain.
    public static let characterLimit = 1_000_000

    /// A parse that takes longer than this is abandoned (no highlights rather than a stall).
    static let parseTimeout: TimeInterval = 2

    public static func highlight(lines: [String], language: SyntaxLanguage) -> [HighlightSpan] {
        let text = lines.joined(separator: "\n")
        let length = text.utf16.count
        guard length > 0, length <= characterLimit else { return [] }
        guard let compiled = CompiledGrammar.shared(for: language) else { return [] }

        var kinds = [UInt8](repeating: 0, count: length)
        guard let tree = parse(text, with: compiled.language) else { return [] }
        var captures = run(query: compiled.query, on: tree, text: text)

        if let inline = compiled.inline, let inlineQuery = compiled.inlineRangesQuery {
            // Markdown: the block grammar marks `inline` nodes; parse each with the inline grammar.
            let ranges = inlineRanges(in: tree, query: inlineQuery)
            if !ranges.isEmpty, let inlineTree = parse(text, with: inline.language, ranges: ranges) {
                captures += run(query: inline.query, on: inlineTree, text: text)
            }
        }
        paint(&kinds, with: captures)
        return spans(from: kinds, lines: lines)
    }

    /// Compiles the language's grammar and query, surfacing any query error (for tests).
    public static func validate(_ language: SyntaxLanguage) throws {
        _ = try CompiledGrammar(language)
    }

    // MARK: - Parsing and querying

    private struct Capture {
        var range: NSRange
        var pattern: Int
        var kind: TokenKind?
    }

    private static func parse(_ text: String, with language: Language, ranges: [TSRange] = []) -> MutableTree? {
        let parser = Parser()
        do { try parser.setLanguage(language) } catch { return nil }
        parser.timeout = parseTimeout
        if !ranges.isEmpty { parser.includedRanges = ranges }
        return parser.parse(text)
    }

    private static func run(query: Query, on tree: MutableTree, text: String) -> [Capture] {
        let cursor = query.execute(in: tree)
        let context = Predicate.Context(textProvider: text.predicateTextProvider)
        var captures: [Capture] = []
        while let match = cursor.next() {
            if !match.predicates.isEmpty, !match.allowed(in: context) { continue }
            for capture in match.captures {
                guard let name = capture.name, let kind = CaptureMapping.kind(for: name) else { continue }
                captures.append(Capture(range: capture.range, pattern: match.patternIndex, kind: kind))
            }
        }
        return captures
    }

    private static func inlineRanges(in tree: MutableTree, query: Query) -> [TSRange] {
        let cursor = query.execute(in: tree)
        var ranges: [TSRange] = []
        while let match = cursor.next() {
            for capture in match.captures { ranges.append(capture.node.tsRange) }
        }
        return ranges.sorted { $0.bytes.lowerBound < $1.bytes.lowerBound }
    }

    // MARK: - Resolution

    /// Outer nodes first, then inner ones over them; the last coloured pattern wins for an
    /// identical range.
    private static func paint(_ kinds: inout [UInt8], with captures: [Capture]) {
        var sorted = captures
        sorted.sort { a, b in
            if a.range.location != b.range.location { return a.range.location < b.range.location }
            if a.range.length != b.range.length { return a.range.length > b.range.length }
            return a.pattern < b.pattern
        }
        var index = 0
        while index < sorted.count {
            var winner = sorted[index]
            var next = index + 1
            while next < sorted.count, sorted[next].range == winner.range {
                if sorted[next].kind != nil { winner = sorted[next] }
                next += 1
            }
            index = next
            guard let kind = winner.kind else { continue }
            let start = max(0, winner.range.location)
            let end = min(kinds.count, winner.range.location + winner.range.length)
            guard start < end else { continue }
            let value = kind.rawValue + 1
            for i in start..<end { kinds[i] = value }
        }
    }

    private static func spans(from kinds: [UInt8], lines: [String]) -> [HighlightSpan] {
        var spans: [HighlightSpan] = []
        var offset = 0
        for (line, text) in lines.enumerated() {
            let length = text.utf16.count
            var column = 0
            while column < length {
                let value = kinds[offset + column]
                var end = column + 1
                while end < length, kinds[offset + end] == value { end += 1 }
                if value != 0, let kind = TokenKind(rawValue: value - 1) {
                    spans.append(HighlightSpan(line: line, range: column..<end, kind: kind))
                }
                column = end
            }
            offset += length + 1
        }
        return spans
    }
}

// MARK: - Compiled grammar cache

/// Grammar plus compiled queries; compiling a query costs a few milliseconds, so one per language
/// is kept for the life of the process. `Query` and `Language` are immutable and `Sendable`.
final class CompiledGrammar: Sendable {
    let language: Language
    let query: Query
    let inline: CompiledGrammar?
    /// Markdown only: finds the block grammar's `inline` nodes.
    let inlineRangesQuery: Query?

    private static let cache = OSAllocatedUnfairLock<[SyntaxLanguage: CompiledGrammar]>(initialState: [:])

    static func shared(for language: SyntaxLanguage) -> CompiledGrammar? {
        if let cached = cache.withLock({ $0[language] }) { return cached }
        guard let compiled = try? CompiledGrammar(language) else { return nil }
        cache.withLock { $0[language] = compiled }
        return compiled
    }

    init(_ syntaxLanguage: SyntaxLanguage) throws {
        let grammar = syntaxLanguage.grammar
        language = grammar.language
        query = try Query(language: grammar.language, data: Data(grammar.queryText.utf8))
        if let inlineGrammar = grammar.inline {
            inline = try CompiledGrammar(language: inlineGrammar.language, queryText: inlineGrammar.queryText)
            inlineRangesQuery = try Query(language: grammar.language, data: Data("(inline) @inline".utf8))
        } else {
            inline = nil
            inlineRangesQuery = nil
        }
    }

    private init(language: Language, queryText: String) throws {
        self.language = language
        query = try Query(language: language, data: Data(queryText.utf8))
        inline = nil
        inlineRangesQuery = nil
    }
}
