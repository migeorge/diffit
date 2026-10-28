/// The handful of token classes the diff panes colour. Grammar capture names (`keyword.return`,
/// `function.method`, `markup.heading`, …) are folded onto these by `CaptureMapping`.
public enum TokenKind: UInt8, CaseIterable, Sendable {
    case keyword
    case function
    case type
    case string
    case escape
    case comment
    case number
    case constant
    case property
    case attribute
    case label
    case tag
    /// Markdown heading text.
    case heading
    /// Markdown `**strong**`.
    case strong
    /// Markdown `*emphasis*`.
    case emphasis
    /// Markdown URLs and link labels.
    case link
    /// Markdown code spans and fenced blocks.
    case codeSpan
}

/// One coloured run inside one source line.
public struct HighlightSpan: Equatable, Sendable {
    public let line: Int
    /// UTF-16 offsets within the line.
    public let range: Range<Int>
    public let kind: TokenKind

    public init(line: Int, range: Range<Int>, kind: TokenKind) {
        self.line = line
        self.range = range
        self.kind = kind
    }
}
