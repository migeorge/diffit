/// Markdown: block structure per line (headings, lists, quotes, fences) and inline marks
/// (code spans, emphasis, links). Fenced code is highlighted as its info-string language.
struct MarkdownScanner: LineScanner {
    func scan(_ line: Line, from start: Int, stopAt: Pattern?, state: inout ScanState, painter: inout LinePainter) -> Int {
        switch state {
        case .fence(let fence, let language, var inner):
            if isFenceClose(line, fence: fence) {
                painter.paint(0..<line.count, .codeSpan)
                state = .none
            } else if let language {
                language.scanner.scan(line, state: &inner, painter: &painter)
                state = .fence(fence: fence, language: language, inner: inner)
            } else {
                painter.paint(0..<line.count, .codeSpan)
            }
            return line.count
        case .blockComment:
            if let close = line.find(Self.commentClose, from: 0) {
                painter.paint(0..<close + 3, .comment)
                state = .none
                scanInline(line, from: close + 3, painter: &painter)
            } else {
                painter.paint(0..<line.count, .comment)
            }
            return line.count
        default:
            break
        }

        let wasParagraph = state == .paragraph
        state = .none
        var index = line.indentation
        guard index < line.count else { return line.count }

        // Block quotes
        let quoted = line.at(index) == ch(">")
        while line.at(index) == ch(">") {
            painter.paint(index..<index + 1, .comment)
            index = line.skipSpaces(from: index + 1)
        }
        // List markers, with task boxes
        if let markerEnd = listMarkerEnd(line, at: index) {
            painter.paint(index..<markerEnd, .keyword)
            index = line.skipSpaces(from: markerEnd)
            if line.at(index) == ch("["), line.at(index + 2) == ch("]"), line.at(index + 3).isSpace || index + 3 == line.count {
                painter.paint(index..<index + 3, .keyword)
                index = line.skipSpaces(from: index + 3)
            }
        } else if line.indentation >= 4, !wasParagraph, !quoted {
            painter.paint(0..<line.count, .codeSpan)
            return line.count
        }
        guard index < line.count else { return line.count }

        if let fence = fenceOpen(line, at: index) {
            painter.paint(index..<line.count, .codeSpan)
            let info = line.string(index + fence.count..<line.count).trimmingCharacters(in: .whitespaces)
            state = .fence(fence: fence, language: SyntaxLanguage(fenceInfo: info), inner: .none)
            return line.count
        }
        if line.has(Self.commentOpen, at: index) {
            if let close = line.find(Self.commentClose, from: index + 4) {
                painter.paint(index..<close + 3, .comment)
                scanInline(line, from: close + 3, painter: &painter)
            } else {
                painter.paint(index..<line.count, .comment)
                state = .blockComment(depth: 1)
            }
            return line.count
        }
        if line.at(index) == ch("#") {
            var level = 0
            while line.at(index + level) == ch("#") { level += 1 }
            if level <= 6, line.at(index + level).isSpace || index + level == line.count {
                painter.paint(index..<line.count, .heading)
                scanInline(line, from: index + level, painter: &painter)
                return line.count
            }
        }
        if let rule = ruleCharacter(line, from: index) {
            if wasParagraph, rule == ch("=") || rule == ch("-") {
                painter.paint(index..<line.count, .heading)
            } else {
                painter.paint(index..<line.count, .keyword)
            }
            return line.count
        }
        if line.at(index) == ch("["), let close = line.find(pattern("]:"), from: index), line.at(close + 2).isSpace || close + 2 == line.count {
            painter.paint(index..<line.count, .link)
            return line.count
        }
        if line.at(index) == ch("|"), isTableSeparator(line, from: index) {
            painter.paint(index..<line.count, .keyword)
            return line.count
        }
        scanInline(line, from: index, painter: &painter)
        if !quoted { state = .paragraph }
        return line.count
    }

    // MARK: - Block helpers

    private static let commentOpen = pattern("<!--")
    private static let commentClose = pattern("-->")

    private func fenceOpen(_ line: Line, at index: Int) -> String? {
        let unit = line.at(index)
        guard unit == ch("`") || unit == ch("~") else { return nil }
        var length = 0
        while line.at(index + length) == unit { length += 1 }
        guard length >= 3 else { return nil }
        if unit == ch("`"), line.find(any: [ch("`")], from: index + length) != nil { return nil }   // inline code, not a fence
        return line.string(index..<index + length)
    }

    private func isFenceClose(_ line: Line, fence: String) -> Bool {
        let index = line.indentation
        guard line.has(pattern(fence), at: index) else { return false }
        var end = index + fence.count
        while line.at(end) == fence.utf16.first { end += 1 }
        return line.skipSpaces(from: end) == line.count
    }

    private func listMarkerEnd(_ line: Line, at index: Int) -> Int? {
        let unit = line.at(index)
        if unit == ch("-") || unit == ch("*") || unit == ch("+") {
            return line.at(index + 1).isSpace ? index + 1 : nil
        }
        guard unit.isASCIIDigit else { return nil }
        var end = index
        while line.at(end).isASCIIDigit { end += 1 }
        guard end - index <= 9, line.at(end) == ch(".") || line.at(end) == ch(")"), line.at(end + 1).isSpace else { return nil }
        return end + 1
    }

    /// The character of a thematic break or setext underline (`---`, `***`, `===`), if the line is one.
    private func ruleCharacter(_ line: Line, from index: Int) -> UInt16? {
        let unit = line.at(index)
        guard unit == ch("-") || unit == ch("*") || unit == ch("_") || unit == ch("=") else { return nil }
        var count = 0
        var cursor = index
        while cursor < line.count {
            let current = line.at(cursor)
            if current == unit { count += 1 } else if !current.isSpace { return nil }
            cursor += 1
        }
        return count >= (unit == ch("=") ? 1 : 3) ? unit : nil
    }

    private func isTableSeparator(_ line: Line, from index: Int) -> Bool {
        var dashes = 0
        for cursor in index..<line.count {
            let unit = line.at(cursor)
            if unit == ch("-") { dashes += 1 } else if !(unit == ch("|") || unit == ch(":") || unit.isSpace) { return false }
        }
        return dashes > 0
    }

    // MARK: - Inline

    func scanInline(_ line: Line, from start: Int, painter: inout LinePainter) {
        var index = start
        var closers: [Int: Int] = [:]   // start → length of a delimiter already matched
        while index < line.count {
            if let length = closers[index] { index += length; continue }
            let unit = line.at(index)
            switch unit {
            case ch("\\"):
                let next = line.at(index + 1)
                if next > 32, next < 127, !next.isIdentifierPart {
                    painter.paint(index..<index + 2, .escape)
                    index += 2
                } else {
                    index += 1
                }
            case ch("`"):
                var run = 0
                while line.at(index + run) == ch("`") { run += 1 }
                if let end = codeSpanEnd(line, from: index + run, run: run) {
                    painter.paint(index..<end, .codeSpan)
                    index = end
                } else {
                    index += run
                }
            case ch("*"), ch("_"):
                var run = 0
                while line.at(index + run) == unit { run += 1 }
                let length = min(run, 2)
                if let close = emphasisClose(line, from: index + run, unit: unit, length: length), canOpen(line, at: index, unit: unit) {
                    painter.paint(index..<close + length, length == 2 ? .strong : .emphasis)
                    closers[close] = length
                    index += length
                } else {
                    index += run
                }
            case ch("["):
                if let end = linkEnd(line, from: index) {
                    let from = line.at(index - 1) == ch("!") ? index - 1 : index
                    painter.paint(from..<end, .link)
                    index = end
                } else {
                    index += 1
                }
            case ch("<"):
                if let end = line.find(any: [ch(">")], from: index + 1), end > index + 1 {
                    let inner = line.string(index + 1..<end)
                    let isAutolink = inner.contains("://") || inner.contains("@") || inner.hasPrefix("mailto:")
                    if isAutolink, !inner.contains(" ") {
                        painter.paint(index..<end + 1, .link)
                        index = end + 1
                    } else if line.at(index + 1).isASCIILetter || line.at(index + 1) == ch("/") || line.at(index + 1) == ch("!") {
                        painter.paint(index..<end + 1, .tag)
                        index = end + 1
                    } else {
                        index += 1
                    }
                } else {
                    index += 1
                }
            case ch("h") where (line.has(Self.http, at: index) || line.has(Self.https, at: index)) && !line.at(index - 1).isIdentifierPart:
                var end = index
                while end < line.count, !line.at(end).isSpace, line.at(end) != ch("<"), line.at(end) != ch(">") { end += 1 }
                while end > index, Self.trailingPunctuation.contains(line.at(end - 1)) { end -= 1 }
                painter.paint(index..<end, .link)
                index = end
            default:
                index += 1
            }
        }
    }

    private static let http = pattern("http://")
    private static let https = pattern("https://")
    private static let trailingPunctuation: Set<UInt16> = [ch("."), ch(","), ch(";"), ch(":"), ch("!"), ch("?"), ch(")")]

    private func codeSpanEnd(_ line: Line, from start: Int, run: Int) -> Int? {
        var cursor = start
        while cursor < line.count {
            if line.at(cursor) == ch("`") {
                var length = 0
                while line.at(cursor + length) == ch("`") { length += 1 }
                if length == run { return cursor + length }
                cursor += length
            } else {
                cursor += 1
            }
        }
        return nil
    }

    private func canOpen(_ line: Line, at index: Int, unit: UInt16) -> Bool {
        let before = line.at(index - 1)
        if unit == ch("_"), before.isIdentifierPart { return false }
        return true
    }

    /// Start of the closing delimiter for an emphasis run opened before `start`.
    private func emphasisClose(_ line: Line, from start: Int, unit: UInt16, length: Int) -> Int? {
        guard !line.at(start).isSpace, start < line.count else { return nil }
        var cursor = start
        while cursor < line.count {
            if line.at(cursor) == unit {
                var run = 0
                while line.at(cursor + run) == unit { run += 1 }
                let before = line.at(cursor - 1)
                let after = line.at(cursor + run)
                let flanking = !before.isSpace && before != unit
                let intraword = unit == ch("_") && after.isIdentifierPart
                if run >= length, flanking, !intraword, cursor > start { return cursor + run - length }
                cursor += run
            } else if line.at(cursor) == ch("`") {
                var run = 0
                while line.at(cursor + run) == ch("`") { run += 1 }
                cursor = codeSpanEnd(line, from: cursor + run, run: run) ?? cursor + run
            } else {
                cursor += 1
            }
        }
        return nil
    }

    /// End of `[text](url)`, `[text][ref]`, `[ref]` or `[^note]` starting at `start`.
    private func linkEnd(_ line: Line, from start: Int) -> Int? {
        var depth = 0
        var cursor = start
        var close: Int?
        while cursor < line.count {
            let unit = line.at(cursor)
            if unit == ch("\\") { cursor += 2; continue }
            if unit == ch("[") { depth += 1 } else if unit == ch("]") { depth -= 1; if depth == 0 { close = cursor; break } }
            cursor += 1
        }
        guard let close else { return nil }
        let next = line.at(close + 1)
        if next == ch("(") {
            var parens = 0
            var end = close + 1
            while end < line.count {
                let unit = line.at(end)
                if unit == ch("(") { parens += 1 } else if unit == ch(")") { parens -= 1; if parens == 0 { return end + 1 } }
                end += 1
            }
            return nil
        }
        if next == ch("["), let refClose = line.find(any: [ch("]")], from: close + 2) { return refClose + 1 }
        if line.at(start + 1) == ch("^") { return close + 1 }
        return close - start > 1 && line.at(start - 1) != ch("!") ? close + 1 : nil
    }
}
