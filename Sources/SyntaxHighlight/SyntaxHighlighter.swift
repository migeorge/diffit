/// Colours a file line by line with the language's scanner, carrying state (open comments,
/// strings, fenced blocks) from one line to the next.
public enum SyntaxHighlighter {
    /// Sides longer than this (UTF-16 units, about 25k lines of code) are not highlighted. Scanning
    /// is cheap, but every coloured run slows the text view's one-shot layout: a 55k-line Go file
    /// takes about 1 s to lay out with colours against 0.3 s without, so very large files stay plain.
    public static let characterLimit = 1_000_000

    public static func highlight(lines: [String], language: SyntaxLanguage) -> [HighlightSpan] {
        var length = 0
        for line in lines {
            length += line.utf16.count + 1
            if length > characterLimit { return [] }
        }
        guard !lines.isEmpty else { return [] }
        let scanner = language.scanner
        var state = ScanState.none
        var spans: [HighlightSpan] = []
        for (number, text) in lines.enumerated() {
            let line = Line(text)
            var painter = LinePainter(count: line.count)
            scanner.scan(line, state: &state, painter: &painter)
            spans += painter.spans(line: number)
        }
        return spans
    }
}
