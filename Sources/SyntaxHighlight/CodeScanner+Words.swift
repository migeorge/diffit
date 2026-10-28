extension CodeScanner {
    // MARK: - Words

    func scanWord(_ line: Line, at index: Int, context: inout Context, state: inout ScanState, painter: inout LinePainter) -> Int {
        var end = line.identifierEnd(from: index, extra: spec.identifierExtra)
        let isCommandWord = spec.commandPosition && context.expectCommand
        if isCommandWord {
            while end < line.count, line.at(end).isIdentifierPart || Self.commandWordParts.contains(line.at(end)) { end += 1 }
        }
        if end == index { end = index + 1 }
        let word = line.string(index..<end)

        if !isCommandWord, line.at(end) == ch("\"") || line.at(end) == ch("'") || line.at(end) == ch("`") || line.at(end) == ch("#"),
           let stringEnd = scanStringStart(line, at: end, prefix: word, paintFrom: index, context: &context, state: &state, painter: &painter) {
            return stringEnd
        }

        var kind = classify(word, in: line, from: index, to: end, context: &context)
        if isCommandWord, kind == .function, context.parenDepth == 0, isCasePattern(line, from: end) {
            kind = nil   // `darwin*)` in a `case`
            context.casePattern = true
        }
        if let kind { painter.paint(index..<end, kind) }

        let after = line.at(line.skipSpaces(from: end))
        if spec.commandPosition {
            if kind == .keyword {
                context.expectCommand = spec.commandTriggers.contains(word)
            } else if isCommandWord, kind == .property, after == ch("=") {
                // `NAME=value cmd`: the command follows the value.
                context.expectCommand = false
                context.assignmentPending = true
            } else if isCommandWord {
                context.expectCommand = spec.commandWrappers.contains(word)
            } else {
                context.expectCommand = false
            }
        }
        context.beforeWord = context.previous
        context.previous = kind == .keyword ? .keyword(word) : .word(word)
        context.previousWordStart = index
        return end
    }

    private func isCasePattern(_ line: Line, from end: Int) -> Bool {
        var cursor = end
        while cursor < line.count, [ch("*"), ch("?"), ch("|"), ch("["), ch("]"), ch("."), ch("-")].contains(line.at(cursor)) || line.at(cursor).isIdentifierPart {
            cursor += 1
        }
        return line.at(cursor) == ch(")")
    }

    private func classify(_ word: String, in line: Line, from index: Int, to end: Int, context: inout Context) -> TokenKind? {
        let key = spec.caseInsensitive ? word.lowercased() : word
        let before = line.at(index - 1)
        let afterIndex = line.skipSpaces(from: end)
        let after = line.at(afterIndex)
        let isMember = spec.memberAccess.contains { line.has($0, at: index - $0.count) }
        let atLineStart = context.previous == .lineStart

        if spec.symbols, let marker = spec.keyMarker, line.has(marker, at: end), line.at(end + 1).isSpace {
            return .property   // Ruby `key: 1`, Elixir `do: expr`
        }
        // Shell keywords (`done`, `then`) are ordinary words in argument position: `echo done`.
        let keywordPosition = !spec.commandPosition || context.expectCommand || word == "in"
        if !isMember {
            if keywordPosition, spec.keywords.contains(key) || (atLineStart && spec.lineStartKeywords.contains(key)) { return .keyword }
            if spec.constants.contains(key) { return .constant }
        }
        if spec.types.contains(key) { return .type }
        if case .keyword(let previous) = context.previous {
            let previousKey = spec.caseInsensitive ? previous.lowercased() : previous
            if spec.functionDefiners.contains(previousKey) { return .function }
            if spec.typeDefiners.contains(previousKey) { return .type }
        }
        if !isMember, spec.builtins.contains(key) { return .function }

        let assigns = after == ch("=") && line.at(afterIndex + 1) != ch("=")
        if spec.commandPosition, context.expectCommand, !word.hasPrefix("-") {
            if assigns, spec.assignmentIsProperty { return .property }
            return .function
        }
        if spec.assignmentIsProperty, assigns, !isMember {
            switch context.previous {
            case .lineStart: return .property
            case .word(let previous) where spec.builtins.contains(previous): return .property
            default: break
            }
        }
        if spec.lineStartFunctions, index == 0, line.at(index).isASCIILower { return .function }
        if spec.macroBang, after == ch("!"), [ch("("), ch("["), ch("{")].contains(line.at(afterIndex + 1)) { return .attribute }

        let first = line.at(index)
        let capitalised = first.isASCIIUpper
        let isCall = spec.callIsFunction && (spec.commandPosition ? line.at(end) == ch("(") : after == ch("(") || isGenericCall(line, from: afterIndex))
        if spec.upperCaseIsConstant, isAllCaps(line, from: index, to: end) { return .constant }
        if isCall, spec.callsBeforeTypes { return .function }
        if capitalised {
            if spec.capitalizedIsType { return .type }
            if spec.typeAfterUnits.contains(before) { return .type }
            if spec.declarationTypes {
                if case .word = context.previous, !isMember { return .type }
                if after == ch("{") { return .type }
                if isMember, qualifiedTypePosition(line, context: context) { return .type }
            }
        }
        for suffix in spec.typeSuffixes where word.hasSuffix(suffix) && word.count > suffix.count { return .type }
        if isCall { return .function }
        if isMember { return .property }
        if let marker = spec.keyMarker, line.has(marker, at: afterIndex), line.at(afterIndex + marker.count) != marker[marker.count - 1],
           context.previous == .lineStart || context.previous == .punctuation(ch(",")) || context.previous == .punctuation(ch("{")) {
            return .property
        }
        return nil
    }

    /// `name<T, U>(`: a call with explicit generic arguments.
    private func isGenericCall(_ line: Line, from index: Int) -> Bool {
        guard line.at(index) == ch("<") else { return false }
        var depth = 0
        var cursor = index
        while cursor < line.count {
            let unit = line.at(cursor)
            if unit == ch("<") { depth += 1 } else if unit == ch(">") { depth -= 1; if depth == 0 { return line.at(cursor + 1) == ch("(") } }
            else if unit == ch(";") || unit == ch("{") || unit == ch("(") || unit == ch(")") { return false }
            cursor += 1
        }
        return false
    }

    /// Go `pkg.Name` where the token before `pkg` says a type is expected (`w http.ResponseWriter`,
    /// `r *http.Request`, `[]time.Time`).
    private func qualifiedTypePosition(_ line: Line, context: Context) -> Bool {
        if case .word = context.beforeWord { return true }
        return spec.typeAfterUnits.contains(line.at(context.previousWordStart - 1))
    }

    private func isAllCaps(_ line: Line, from start: Int, to end: Int) -> Bool {
        guard end - start > 1 else { return false }
        var letters = 0
        for index in start..<end {
            let unit = line.at(index)
            if unit.isASCIIUpper { letters += 1 } else if !(unit.isASCIIDigit || unit == ch("_")) { return false }
        }
        return letters > 0
    }

    // MARK: - Prefixed tokens

    /// `$name`, `${…}`, `@name` → property.
    func scanVariable(_ line: Line, at index: Int, context: inout Context, painter: inout LinePainter) -> Int? {
        for prefix in spec.variablePrefixes where line.has(prefix, at: index) {
            let start = index + prefix.count
            let next = line.at(start)
            var end: Int
            if next == ch("{") {
                end = matchingBracket(line, from: start, open: ch("{"), close: ch("}"))
            } else if next.isIdentifierStart {
                end = line.identifierEnd(from: start)
            } else if next.isASCIIDigit || spec.variableSpecials.contains(next) {
                end = start + 1
            } else {
                continue
            }
            painter.paint(index..<end, .property)
            context.previous = .word("")
            return end
        }
        return nil
    }

    /// `@name` → attribute, unless the spec lists `@name` as a keyword.
    func scanAttribute(_ line: Line, at index: Int, context: inout Context, painter: inout LinePainter) -> Int? {
        guard let prefix = spec.attributePrefix, line.has(prefix, at: index) else { return nil }
        let start = index + prefix.count
        guard line.at(start).isIdentifierStart else { return nil }
        var end = line.identifierEnd(from: start)
        while line.at(end) == ch("."), line.at(end + 1).isIdentifierStart { end = line.identifierEnd(from: end + 1) }
        let word = line.string(index..<end)
        let isKeyword = spec.keywords.contains(word)
        painter.paint(index..<end, isKeyword ? .keyword : .attribute)
        context.previous = isKeyword ? .keyword(word) : .word(word)
        return end
    }

    /// Ruby and Elixir `:atom` / `:"quoted atom"` → constant.
    func scanSymbol(_ line: Line, at index: Int, context: inout Context, painter: inout LinePainter) -> Int? {
        guard line.at(index) == ch(":") else { return nil }
        let before = line.at(index - 1)
        guard !(before.isIdentifierPart || before == ch(":") || before == ch("?")) else { return nil }
        let next = line.at(index + 1)
        var end: Int
        if next.isIdentifierStart {
            end = line.identifierEnd(from: index + 1, extra: spec.identifierExtra)
        } else if next == ch("\""), let close = line.find(any: [ch("\"")], from: index + 2) {
            end = close + 1
        } else {
            return nil
        }
        painter.paint(index..<end, .constant)
        context.previous = .word("")
        return end
    }

    /// JSX `<Name` / `</Name` in expression position → tag.
    func scanJSXTag(_ line: Line, at index: Int, context: inout Context, painter: inout LinePainter) -> Int? {
        var start = index + 1
        if line.at(start) == ch("/") {
            start += 1
        } else {
            switch context.previous {
            case .lineStart, .punctuation, .keyword: break
            default: return nil
            }
        }
        guard line.at(start).isIdentifierStart else { return nil }
        var end = line.identifierEnd(from: start)
        while line.at(end) == ch(".") || line.at(end) == ch("-"), line.at(end + 1).isIdentifierStart { end = line.identifierEnd(from: end + 1) }
        painter.paint(index..<end, .tag)
        context.previous = .word("")
        return end
    }
}
