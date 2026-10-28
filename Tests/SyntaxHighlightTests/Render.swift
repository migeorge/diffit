import Foundation
@testable import SyntaxHighlight

/// Renders highlighted lines as text with coloured runs wrapped as `[k:func]`, for assertions
/// and for eyeballing fixtures: k keyword, f function, t type, s string, e escape, c comment,
/// n number, C constant, p property, a attribute, l label, g tag, h heading, b strong, i emphasis,
/// L link, ` code span.
enum Render {
    static let codes: [TokenKind: String] = [
        .keyword: "k", .function: "f", .type: "t", .string: "s", .escape: "e", .comment: "c", .number: "n", .constant: "C",
        .property: "p", .attribute: "a", .label: "l", .tag: "g", .heading: "h", .strong: "b", .emphasis: "i", .link: "L",
        .codeSpan: "`",
    ]

    static func lines(_ source: [String], _ language: SyntaxLanguage) -> [String] {
        let spans = SyntaxHighlighter.highlight(lines: source, language: language)
        return source.enumerated().map { number, text in
            let units = Array(text.utf16)
            var output = ""
            var column = 0
            for span in spans where span.line == number {
                output += String(utf16CodeUnits: Array(units[column..<span.range.lowerBound]), count: span.range.lowerBound - column)
                let run = String(utf16CodeUnits: Array(units[span.range]), count: span.range.count)
                output += "[\(codes[span.kind] ?? "?"):\(run)]"
                column = span.range.upperBound
            }
            output += String(utf16CodeUnits: Array(units[column...]), count: units.count - column)
            return output
        }
    }

    static func text(_ source: String, _ language: SyntaxLanguage) -> String {
        lines(source.components(separatedBy: "\n"), language).joined(separator: "\n")
    }

    /// Every coloured run as (text, kind).
    static func tokens(_ source: [String], _ language: SyntaxLanguage) -> [(String, TokenKind)] {
        SyntaxHighlighter.highlight(lines: source, language: language).map { span in
            let line = source[span.line] as NSString
            return (line.substring(with: NSRange(location: span.range.lowerBound, length: span.range.count)), span.kind)
        }
    }
}
