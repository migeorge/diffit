/// CSS (and the SCSS/Less subset that reads the same): selectors outside braces, declarations inside.
struct CSSScanner: LineScanner {
    func scan(_ line: Line, from start: Int, stopAt: Pattern?, state: inout ScanState, painter: inout LinePainter) -> Int {
        var depth = 0
        var index = start
        switch state {
        case .blockComment:
            guard let close = line.find(Self.commentClose, from: index) else {
                painter.paint(index..<line.count, .comment)
                return line.count
            }
            painter.paint(index..<close + 2, .comment)
            index = close + 2
        case .depth(let value):
            depth = value
        default:
            break
        }
        state = .none

        while index < line.count {
            if let stopAt, line.hasCaseInsensitive(stopAt, at: index) {
                state = depth > 0 ? .depth(depth) : .none
                return index
            }
            let unit = line.at(index)
            if unit.isSpace { index += 1; continue }
            if line.has(Self.commentOpen, at: index) {
                guard let close = line.find(Self.commentClose, from: index + 2) else {
                    painter.paint(index..<line.count, .comment)
                    state = .blockComment(depth: 1)
                    return line.count
                }
                painter.paint(index..<close + 2, .comment)
                index = close + 2
                continue
            }
            if line.has(Self.lineComment, at: index) {
                painter.paint(index..<line.count, .comment)
                break
            }
            if unit == ch("{") { depth += 1; index += 1; continue }
            if unit == ch("}") { depth = max(0, depth - 1); index += 1; continue }
            if unit == ch("\"") || unit == ch("'") {
                let close = line.find(any: [unit], from: index + 1).map { $0 + 1 } ?? line.count
                painter.paint(index..<close, .string)
                index = close
                continue
            }
            index = depth == 0 || startsRule(line, from: index) ? scanSelectorToken(line, at: index, painter: &painter)
                                                                : scanDeclarationToken(line, at: index, painter: &painter)
        }
        state = depth > 0 ? .depth(depth) : .none
        return line.count
    }

    private static let commentOpen = pattern("/*")
    private static let commentClose = pattern("*/")
    private static let lineComment = pattern("//")
    private static let nameUnits: Set<UInt16> = [ch("-")]

    /// Inside a block, a run that reaches `{` before `;` or `}` is a nested rule's selector.
    private func startsRule(_ line: Line, from start: Int) -> Bool {
        var cursor = start
        while cursor < line.count {
            switch line.at(cursor) {
            case ch("{"): return true
            case ch(";"), ch("}"): return false
            default: cursor += 1
            }
        }
        return false
    }

    private func scanSelectorToken(_ line: Line, at index: Int, painter: inout LinePainter) -> Int {
        let unit = line.at(index)
        let next = line.at(index + 1)
        if unit == ch("@"), next.isIdentifierStart {
            let end = line.identifierEnd(from: index + 1, extra: Self.nameUnits)
            painter.paint(index..<end, .keyword)
            return end
        }
        if unit == ch("."), next.isIdentifierStart || next == ch("-") {
            let end = line.identifierEnd(from: index + 1, extra: Self.nameUnits)
            painter.paint(index..<end, .property)
            return end
        }
        if unit == ch("#"), next.isIdentifierStart || next == ch("-") {
            let end = line.identifierEnd(from: index + 1, extra: Self.nameUnits)
            painter.paint(index..<end, .constant)
            return end
        }
        if unit == ch(":"), !next.isSpace {
            var start = index + 1
            if line.at(start) == ch(":") { start += 1 }
            let end = line.identifierEnd(from: start, extra: Self.nameUnits)
            painter.paint(index..<end, .keyword)
            return max(end, index + 1)
        }
        if unit == ch("[") {
            let end = line.find(any: [ch("]")], from: index).map { $0 + 1 } ?? line.count
            painter.paint(index..<end, .attribute)
            return end
        }
        if unit == ch("$"), next.isIdentifierStart {
            let end = line.identifierEnd(from: index + 1, extra: Self.nameUnits)
            painter.paint(index..<end, .property)
            return end
        }
        if unit.isIdentifierStart || (unit == ch("-") && next == ch("-")) {
            let end = line.identifierEnd(from: index, extra: Self.nameUnits)
            if line.at(end) == ch(":"), line.at(end + 1).isSpace {
                painter.paint(index..<end, .property)   // `@media (max-width: 600px)`
            } else {
                painter.paint(index..<end, line.at(end) == ch("(") ? .function : .tag)
            }
            return end
        }
        if unit.isASCIIDigit { return scanNumber(line, at: index, painter: &painter) }
        return index + 1
    }

    private func scanDeclarationToken(_ line: Line, at index: Int, painter: inout LinePainter) -> Int {
        let unit = line.at(index)
        let next = line.at(index + 1)
        if unit == ch("!") {
            let end = line.identifierEnd(from: index + 1)
            painter.paint(index..<end, .keyword)
            return end
        }
        if unit == ch("#"), next.isHexDigit {
            var end = index + 1
            while line.at(end).isHexDigit { end += 1 }
            painter.paint(index..<end, .number)
            return end
        }
        if unit == ch("@"), next.isIdentifierStart {
            let end = line.identifierEnd(from: index + 1, extra: Self.nameUnits)
            painter.paint(index..<end, .keyword)
            return end
        }
        if unit == ch("$"), next.isIdentifierStart {
            let end = line.identifierEnd(from: index + 1, extra: Self.nameUnits)
            painter.paint(index..<end, .property)
            return end
        }
        if unit.isASCIIDigit || (unit == ch("-") && next.isASCIIDigit) || (unit == ch(".") && next.isASCIIDigit) {
            return scanNumber(line, at: index, painter: &painter)
        }
        if unit.isIdentifierStart || (unit == ch("-") && (next == ch("-") || next.isIdentifierStart)) {
            let end = line.identifierEnd(from: index, extra: Self.nameUnits)
            let after = line.skipSpaces(from: end)
            if line.at(after) == ch(":") {
                painter.paint(index..<end, .property)
            } else if line.at(end) == ch("(") {
                painter.paint(index..<end, .function)
            } else if line.at(after) == ch("{") || line.at(after) == ch(",") {
                painter.paint(index..<end, .tag)   // nested rule (SCSS)
            }
            return end
        }
        return index + 1
    }

    private func scanNumber(_ line: Line, at index: Int, painter: inout LinePainter) -> Int {
        var end = index + 1
        while end < line.count {
            let unit = line.at(end)
            if unit.isASCIIDigit || unit == ch(".") || unit == ch("%") || unit.isASCIILetter { end += 1 } else { break }
        }
        painter.paint(index..<end, .number)
        return end
    }
}
