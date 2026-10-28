/// YAML: keys, list markers, anchors, tags, block scalars and typed plain scalars.
struct YAMLScanner: LineScanner {
    func scan(_ line: Line, from start: Int, stopAt: Pattern?, state: inout ScanState, painter: inout LinePainter) -> Int {
        if case .blockScalar(let indent) = state {
            if line.isBlank || line.indentation > indent {
                painter.paint(0..<line.count, .string)
                return line.count
            }
            state = .none
        }
        var index = line.indentation
        if index == 0, line.has(Self.documentStart, at: 0) || line.has(Self.documentEnd, at: 0) {
            painter.paint(0..<3, .keyword)
            index = 3
        }
        index = line.skipSpaces(from: index)
        // List markers, possibly nested on one line (`- - a`)
        while line.at(index) == ch("-"), line.at(index + 1).isSpace || index + 1 == line.count {
            painter.paint(index..<index + 1, .keyword)
            index = line.skipSpaces(from: index + 1)
        }
        guard index < line.count else { return line.count }
        if line.at(index) == ch("#") {
            painter.paint(index..<line.count, .comment)
            return line.count
        }
        if let (keyEnd, valueStart) = key(line, from: index) {
            painter.paint(index..<keyEnd, .property)
            index = line.skipSpaces(from: valueStart)
        }
        scanValue(line, from: index, state: &state, painter: &painter)
        return line.count
    }

    private static let documentStart = pattern("---")
    private static let documentEnd = pattern("...")
    private static let flowUnits: Set<UInt16> = [ch(","), ch("["), ch("]"), ch("{"), ch("}")]

    /// A mapping key ending in `:` followed by a space or the line end.
    private func key(_ line: Line, from start: Int) -> (keyEnd: Int, valueStart: Int)? {
        let unit = line.at(start)
        if unit == ch("\"") || unit == ch("'") {
            guard let close = line.find(any: [unit], from: start + 1) else { return nil }
            guard line.at(close + 1) == ch(":"), line.at(close + 2).isSpace || close + 2 == line.count else { return nil }
            return (close + 1, close + 2)
        }
        guard unit != ch("["), unit != ch("{"), unit != ch("&"), unit != ch("*"), unit != ch("!") else { return nil }
        var cursor = start
        while cursor < line.count {
            let current = line.at(cursor)
            if current == ch("#"), line.at(cursor - 1).isSpace { return nil }
            if current == ch(":"), line.at(cursor + 1).isSpace || cursor + 1 == line.count { return (cursor, cursor + 1) }
            cursor += 1
        }
        return nil
    }

    private func scanValue(_ line: Line, from start: Int, state: inout ScanState, painter: inout LinePainter) {
        var index = start
        while index < line.count {
            let unit = line.at(index)
            if unit.isSpace { index += 1; continue }
            if unit == ch("#"), index == 0 || line.at(index - 1).isSpace {
                painter.paint(index..<line.count, .comment)
                return
            }
            if unit == ch("&") || unit == ch("*") {
                let end = line.identifierEnd(from: index + 1, extra: [ch("-")])
                painter.paint(index..<end, .label)
                index = max(end, index + 1)
                continue
            }
            if unit == ch("!") {
                var end = index + 1
                while end < line.count, !line.at(end).isSpace { end += 1 }
                painter.paint(index..<end, .type)
                index = end
                continue
            }
            if unit == ch("|") || unit == ch(">") {
                var end = index + 1
                while line.at(end) == ch("-") || line.at(end) == ch("+") || line.at(end).isASCIIDigit { end += 1 }
                if line.skipSpaces(from: end) == line.count || line.at(line.skipSpaces(from: end)) == ch("#") {
                    painter.paint(index..<end, .keyword)
                    state = .blockScalar(indent: line.indentation)
                    index = end
                    continue
                }
            }
            if unit == ch("\"") || unit == ch("'") {
                let close = line.find(any: [unit], from: index + 1).map { $0 + 1 } ?? line.count
                painter.paint(index..<close, .string)
                index = close
                continue
            }
            if Self.flowUnits.contains(unit) { index += 1; continue }
            // A plain scalar runs to a flow separator or a ` #` comment.
            var end = index
            while end < line.count {
                let current = line.at(end)
                if Self.flowUnits.contains(current) { break }
                if current == ch("#"), line.at(end - 1).isSpace { break }
                if current == ch(":"), line.at(end + 1).isSpace || end + 1 == line.count { break }
                end += 1
            }
            while end > index, line.at(end - 1).isSpace { end -= 1 }
            if end == index { index += 1; continue }
            if line.at(end) == ch(":") {
                painter.paint(index..<end, .property)   // key inside a flow mapping
            } else if let kind = scalarKind(line.string(index..<end)) {
                painter.paint(index..<end, kind)
            }
            index = end
        }
    }

    private static let constants: Set<String> = ["true", "false", "null", "~", "yes", "no", "on", "off", "True", "False", "Null",
                                                 "TRUE", "FALSE", "NULL", "Yes", "No", "On", "Off", ".inf", "-.inf", ".nan"]

    private func scalarKind(_ text: String) -> TokenKind? {
        if Self.constants.contains(text) { return .constant }
        guard let first = text.utf16.first, first.isASCIIDigit || ((first == ch("-") || first == ch("+")) && text.utf16.count > 1) else { return nil }
        let numeric = text.utf16.dropFirst().allSatisfy { $0.isASCIIDigit || $0 == ch(".") || $0 == ch("_") || $0 == ch("-") || $0 == ch(":")
            || $0 == ch("e") || $0 == ch("E") || $0 == ch("x") || $0 == ch("T") || $0 == ch("Z") || $0 == ch("+") || $0.isHexDigit }
        return numeric ? .number : nil
    }
}
