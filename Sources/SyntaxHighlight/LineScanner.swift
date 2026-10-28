/// Highlights one line at a time, carrying `state` across lines.
protocol LineScanner: Sendable {
    /// Scans `line` from `start`, painting tokens. Returns the index it stopped at: `line.count`
    /// unless `stopAt` was found at a token boundary (used when embedded in another language).
    func scan(_ line: Line, from start: Int, stopAt: Pattern?, state: inout ScanState, painter: inout LinePainter) -> Int
}

extension LineScanner {
    func scan(_ line: Line, state: inout ScanState, painter: inout LinePainter) {
        _ = scan(line, from: 0, stopAt: nil, state: &state, painter: &painter)
    }
}
