/// Collects coloured runs for one line. Later paints win, so scanners paint outer constructs
/// first (a string) and inner ones after (an escape inside it).
struct LinePainter {
    private var kinds: [UInt8]

    init(count: Int) { kinds = [UInt8](repeating: 0, count: count) }

    mutating func paint(_ range: Range<Int>, _ kind: TokenKind) {
        let lower = max(0, range.lowerBound), upper = min(kinds.count, range.upperBound)
        guard lower < upper else { return }
        let value = kind.rawValue + 1
        for index in lower..<upper { kinds[index] = value }
    }

    mutating func paint(from start: Int, to end: Int, _ kind: TokenKind) { paint(start..<end, kind) }

    func spans(line: Int) -> [HighlightSpan] {
        var spans: [HighlightSpan] = []
        var column = 0
        while column < kinds.count {
            let value = kinds[column]
            var end = column + 1
            while end < kinds.count, kinds[end] == value { end += 1 }
            if value != 0, let kind = TokenKind(rawValue: value - 1) {
                spans.append(HighlightSpan(line: line, range: column..<end, kind: kind))
            }
            column = end
        }
        return spans
    }
}
