/// What carries over from one line to the next: the construct the previous line ended inside.
indirect enum ScanState: Equatable {
    case none
    /// Inside a block comment; `depth` > 1 only for languages with nesting comments.
    case blockComment(depth: Int)
    /// Inside a multi-line string of the language's `strings[style]`; `hashes` for raw strings
    /// delimited by `#"…"#` or `r##"…"##`.
    case string(style: Int, hashes: Int)
    /// Inside a heredoc body until a line equal to `terminator` (leading tabs allowed when `indented`).
    case heredoc(terminator: String, indented: Bool)
    /// The previous line ended with a backslash, so this one continues it; `command` when the
    /// next word still names a shell command (the line ended with `&&`, `|`, `;`).
    case continuation(command: Bool)
    /// Markdown: inside a fenced code block opened with `fence`, highlighted as `language`.
    case fence(fence: String, language: SyntaxLanguage?, inner: ScanState)
    /// Markdown: the previous line was paragraph text (a following `===` line is a heading).
    case paragraph
    /// Markup: inside a region scanned by another language (`<script>`, `<?php`) until `close`.
    case embedded(SyntaxLanguage, close: String, inner: ScanState)
    /// Markup: inside a tag whose attributes continue on the next line.
    case insideTag(name: String)
    /// Markup: inside a region painted as one kind until `close` (CDATA, processing instruction).
    case rawBlock(close: String, kind: TokenKind)
    /// YAML: inside a block scalar (`|` or `>`) more indented than `indent`.
    case blockScalar(indent: Int)
    /// A scanner-private counter (CSS brace depth).
    case depth(Int)
}
