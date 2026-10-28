extension CodeScanner {
    // MARK: - Comments

    /// Scans a block comment body; returns the index after the close, or nil (state set) when it
    /// runs past the line end.
    func scanBlockCommentBody(_ line: Line, from start: Int, depth: Int, paintFrom: Int, state: inout ScanState,
                              painter: inout LinePainter) -> Int? {
        guard let block = spec.blockComment else { return start }
        var depth = depth
        var index = start
        while index < line.count {
            if spec.nestedComments, line.has(block.open, at: index) {
                depth += 1
                index += block.open.count
            } else if line.has(block.close, at: index) {
                depth -= 1
                index += block.close.count
                if depth == 0 {
                    painter.paint(paintFrom..<index, .comment)
                    return index
                }
            } else {
                index += 1
            }
        }
        painter.paint(paintFrom..<line.count, .comment)
        state = .blockComment(depth: depth)
        return nil
    }

    // MARK: - Strings

    /// Tries every string style at `index` (after an optional `prefix` word that started at `paintFrom`).
    func scanStringStart(_ line: Line, at index: Int, prefix: String?, paintFrom: Int? = nil, context: inout Context,
                         state: inout ScanState, painter: inout LinePainter) -> Int? {
        for (styleIndex, style) in spec.strings.enumerated() {
            if let prefix {
                guard style.prefixes.contains(prefix.lowercased()) else { continue }
            }
            var hashes = 0
            if style.hashes {
                while line.at(index + hashes) == ch("#") { hashes += 1 }
                guard hashes > 0 else { continue }
            }
            guard line.has(style.open, at: index + hashes) else { continue }
            context.previous = .string
            let bodyStart = index + hashes + style.open.count
            return scanStringBody(line, from: bodyStart, style: style, styleIndex: styleIndex, hashes: hashes, prefix: prefix,
                                  paintFrom: paintFrom ?? index, state: &state, painter: &painter) ?? line.count
        }
        return nil
    }

    /// Paints a string body from `paintFrom`; returns the index after the closing delimiter, or nil
    /// when the string continues on the next line (state set) or is left unterminated.
    func scanStringBody(_ line: Line, from start: Int, style: StringStyle, styleIndex: Int, hashes: Int, prefix: String?,
                        paintFrom: Int, state: inout ScanState, painter: inout LinePainter) -> Int? {
        let lowered = prefix?.lowercased() ?? ""
        let escapes = style.escapes && !lowered.contains("r")
        let interpolates = style.interpolationPrefix.map { letters in lowered.contains { letters.contains($0) } } ?? true
        let interpolations = interpolates ? style.interpolation : []
        var index = start
        var marks: [(Range<Int>, TokenKind)] = []

        while index < line.count {
            let unit = line.at(index)
            if let (range, next) = interpolation(in: line, at: index, styles: interpolations) {
                marks.append((range, .escape))
                index = next
                continue
            }
            if escapes, unit == ch("\\") {
                var end = min(line.count, index + 2)
                let kind = line.at(index + 1)
                if kind == ch("u"), line.at(index + 2) == ch("{"), let close = line.find(any: [ch("}")], from: index) {
                    end = close + 1
                } else if let digits = Self.hexEscapeDigits[kind] {
                    while end < line.count, end < index + 2 + digits, line.at(end).isHexDigit { end += 1 }
                }
                marks.append((index..<end, .escape))
                index = end
                continue
            }
            if line.has(style.close, at: index), closesWithHashes(line, at: index + style.close.count, hashes: hashes) {
                let end = index + style.close.count + hashes
                painter.paint(paintFrom..<end, style.kind)
                for (range, kind) in marks { painter.paint(range, kind) }
                if let key = spec.keyMarker, style.kind == .string {
                    let after = line.skipSpaces(from: end)
                    if line.has(key, at: after), line.at(after + key.count) != key[key.count - 1] {
                        painter.paint(paintFrom..<end, .property)
                    }
                }
                return end
            }
            index += 1
        }

        painter.paint(paintFrom..<line.count, style.kind)
        for (range, kind) in marks { painter.paint(range, kind) }
        if style.multiline { state = .string(style: styleIndex, hashes: hashes) }
        return nil
    }

    /// `\x00`, `\u0041`, `\U0001F600`: how many hex digits follow the escape letter.
    private static let hexEscapeDigits: [UInt16: Int] = [ch("x"): 2, ch("u"): 4, ch("U"): 8]

    private func closesWithHashes(_ line: Line, at index: Int, hashes: Int) -> Bool {
        for offset in 0..<hashes where line.at(index + offset) != ch("#") { return false }
        return true
    }

    private func interpolation(in line: Line, at index: Int, styles: [Interpolation]) -> (Range<Int>, Int)? {
        for style in styles where line.has(style.open, at: index) {
            let after = index + style.open.count
            guard let close = style.close else {
                // `$name`, `$1`, `$?`
                let next = line.at(after)
                if next.isIdentifierStart {
                    let end = line.identifierEnd(from: after)
                    return (index..<end, end)
                }
                if next.isASCIIDigit || spec.variableSpecials.contains(next) { return (index..<after + 1, after + 1) }
                continue
            }
            // `{{` in f-strings is a literal brace.
            if style.open.count == 1, line.at(after) == style.open[0] { return (after..<after, after + 1) }
            guard let openUnit = style.open.last, let closeUnit = close.first else { continue }
            if openUnit == closeUnit {
                guard let closeIndex = line.find(any: [closeUnit], from: after) else { continue }
                return (index..<closeIndex + 1, closeIndex + 1)
            }
            let end = matchingBracket(line, from: index + style.open.count - 1, open: openUnit, close: closeUnit)
            guard end <= line.count, line.at(end - 1) == closeUnit else { continue }
            return (index..<end, end)
        }
        return nil
    }

    // MARK: - Numbers

    func scanNumber(_ line: Line, at index: Int, context: inout Context, painter: inout LinePainter) -> Int {
        var end = index
        if line.at(index) == ch("0"), [ch("x"), ch("X"), ch("b"), ch("B"), ch("o"), ch("O")].contains(line.at(index + 1)) {
            end = index + 2
        }
        while end < line.count {
            let unit = line.at(end)
            if unit.isIdentifierPart || spec.numberExtra.contains(unit) {
                if (unit == ch("e") || unit == ch("E")), line.at(end + 1) == ch("+") || line.at(end + 1) == ch("-"),
                   line.at(end + 2).isASCIIDigit, !line.has(pattern("0x"), at: index) {
                    end += 2
                    continue
                }
                end += 1
            } else if unit == ch("."), line.at(end + 1).isASCIIDigit {
                end += 1
            } else {
                break
            }
        }
        painter.paint(index..<end, .number)
        context.previous = .number
        return end
    }

    // MARK: - Heredocs

    func scanHeredocOperator(_ line: Line, at index: Int, style: HeredocStyle, context: inout Context, painter: inout LinePainter) -> Int? {
        guard line.at(index) == ch("<"), line.at(index + 1) == ch("<") else { return nil }
        var cursor = index + 2
        var indented = false
        switch style {
        case .shell:
            if line.at(cursor) == ch("<") { return nil }   // `<<<` here-string
            if line.at(cursor) == ch("-") { indented = true; cursor += 1 }
        case .ruby:
            if line.at(cursor) == ch("~") || line.at(cursor) == ch("-") { indented = true; cursor += 1 }
        case .php:
            guard line.at(cursor) == ch("<") else { return nil }
            cursor += 1
        }
        cursor = line.skipSpaces(from: cursor)
        let quote = line.at(cursor)
        let quoted = quote == ch("'") || quote == ch("\"")
        if quoted { cursor += 1 }
        guard line.at(cursor).isIdentifierStart else { return nil }
        let end = line.identifierEnd(from: cursor)
        if style == .ruby, !quoted, !line.at(cursor).isASCIIUpper { return nil }   // `a << b` is a shift
        let terminator = line.string(cursor..<end)
        let close = quoted && line.at(end) == quote ? end + 1 : end
        painter.paint(cursor..<end, .string)
        context.pendingHeredoc = (terminator, indented)
        context.previous = .string
        return close
    }

    func scanHeredocLine(_ line: Line, terminator: String, indented: Bool, state: inout ScanState, painter: inout LinePainter) {
        painter.paint(0..<line.count, .string)
        let start = indented ? line.indentation : 0
        var end = line.count
        if spec.heredocs == .php, line.at(end - 1) == ch(";") { end -= 1 }
        if line.string(start..<end) == terminator {
            state = .none
            return
        }
        guard spec.variablePrefixes.contains(pattern("$")) else { return }
        var index = 0
        while index < line.count {
            if line.at(index) == ch("$"), let (range, next) = interpolation(in: line, at: index, styles: [.dollarBrace, .dollarName]) {
                painter.paint(range, .escape)
                index = next
            } else {
                index += 1
            }
        }
    }

    // MARK: - Regex literals and sigils

    func scanRegex(_ line: Line, at index: Int, context: inout Context, painter: inout LinePainter) -> Int? {
        switch context.previous {
        case .lineStart, .punctuation, .keyword: break
        default: return nil
        }
        let next = line.at(index + 1)
        guard next != ch("/"), next != ch("*"), !next.isSpace else { return nil }
        var cursor = index + 1
        var inClass = false
        while cursor < line.count {
            let unit = line.at(cursor)
            if unit == ch("\\") { cursor += 2; continue }
            if unit == ch("[") { inClass = true } else if unit == ch("]") { inClass = false }
            if unit == ch("/"), !inClass {
                var end = cursor + 1
                while line.at(end).isASCIILetter { end += 1 }
                painter.paint(index..<end, .string)
                context.previous = .string
                return end
            }
            cursor += 1
        }
        return nil
    }

    func scanSigil(_ line: Line, at index: Int, painter: inout LinePainter) -> Int? {
        var cursor = index + 1
        guard line.at(cursor).isASCIILetter else { return nil }
        while line.at(cursor).isASCIILetter { cursor += 1 }
        let open = line.at(cursor)
        let pairs: [UInt16: UInt16] = [ch("("): ch(")"), ch("["): ch("]"), ch("{"): ch("}"), ch("<"): ch(">"),
                                       ch("/"): ch("/"), ch("|"): ch("|"), ch("\""): ch("\""), ch("'"): ch("'")]
        guard let close = pairs[open] else { return nil }
        var end = open == close ? (line.find(any: [close], from: cursor + 1).map { $0 + 1 } ?? line.count)
                                : matchingBracket(line, from: cursor, open: open, close: close)
        while line.at(end).isASCIILetter { end += 1 }
        painter.paint(index..<end, .string)
        return end
    }
}
