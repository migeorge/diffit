/// The table-driven scanner behind every code language: comments, strings, numbers and words,
/// classified by `LanguageSpec` and a few positional heuristics (what came before, what follows).
struct CodeScanner: LineScanner {
    let spec: LanguageSpec

    /// The token before the current one, for the heuristics that depend on it.
    enum Previous: Equatable {
        case lineStart
        case word(String)
        case keyword(String)
        case number
        case string
        case closeBracket
        case punctuation(UInt16)
    }

    struct Context {
        var previous: Previous = .lineStart
        /// Shells: the next word names a command.
        var expectCommand: Bool
        /// A heredoc operator seen on this line; its body starts on the next.
        var pendingHeredoc: (terminator: String, indented: Bool)?
        /// Shells: a `NAME=value` prefix was just scanned; the command follows the next blank.
        var assignmentPending = false
        /// Shells: a `case` pattern was just scanned; the command follows its `)`.
        var casePattern = false
        /// Shells: open parentheses on this line (a `)` with none open ends a `case` pattern).
        var parenDepth = 0
        /// The token before the last word, and where that word started (Go qualified types).
        var beforeWord: Previous = .lineStart
        var previousWordStart = -1
    }

    init(_ spec: LanguageSpec) { self.spec = spec }

    func scan(_ line: Line, from start: Int, stopAt: Pattern?, state: inout ScanState, painter: inout LinePainter) -> Int {
        var index = start
        var context = Context(expectCommand: spec.commandPosition)

        switch state {
        case .blockComment(let depth):
            state = .none
            guard let end = scanBlockCommentBody(line, from: index, depth: depth, paintFrom: index, state: &state, painter: &painter) else {
                return line.count
            }
            index = end
        case .string(let style, let hashes) where style < spec.strings.count:
            state = .none
            guard let end = scanStringBody(line, from: index, style: spec.strings[style], styleIndex: style, hashes: hashes,
                                           prefix: nil, paintFrom: index, state: &state, painter: &painter) else { return line.count }
            index = end
            context.previous = .string
        case .heredoc(let terminator, let indented):
            scanHeredocLine(line, terminator: terminator, indented: indented, state: &state, painter: &painter)
            return line.count
        case .continuation(let command):
            state = .none
            context.expectCommand = command
            context.previous = .punctuation(ch("\\"))
        default:
            state = .none
        }

        while index < line.count {
            if let stopAt, line.hasCaseInsensitive(stopAt, at: index) {
                finishLine(line, context: context, state: &state)
                return index
            }
            if line.at(index).isSpace {
                if context.assignmentPending {
                    context.assignmentPending = false
                    context.expectCommand = true
                }
                index += 1
                continue
            }
            let next = scanToken(line, at: index, context: &context, state: &state, painter: &painter)
            index = max(next, index + 1)
            if state != .none { return line.count }   // a multi-line construct swallowed the rest
        }
        finishLine(line, context: context, state: &state)
        return line.count
    }

    // MARK: - Tokens

    private func scanToken(_ line: Line, at index: Int, context: inout Context, state: inout ScanState, painter: inout LinePainter) -> Int {
        let unit = line.at(index)
        let atLineStart = context.previous == .lineStart

        if let pragma = spec.pragma, line.has(pragma.open, at: index) {
            let end = line.find(pragma.close, from: index + pragma.open.count).map { $0 + pragma.close.count } ?? line.count
            painter.paint(index..<end, .attribute)
            context.previous = .punctuation(unit)
            return end
        }
        if spec.preprocessor != .none, unit == ch("#"), line.at(index + 1).isIdentifierStart,
           spec.preprocessor == .anywhere || atLineStart {
            return scanDirective(line, at: index, context: &context, painter: &painter)
        }
        if spec.bracketAttributes, unit == ch("#") {
            let open = line.at(index + 1) == ch("[") ? index + 1 : (line.has(pattern("![" ), at: index + 1) ? index + 2 : nil)
            if let open {
                let end = matchingBracket(line, from: open, open: ch("["), close: ch("]"))
                painter.paint(index..<end, .attribute)
                context.previous = .punctuation(unit)
                return end
            }
        }
        if let block = spec.blockComment, line.has(block.open, at: index) {
            context.previous = .punctuation(unit)
            return scanBlockCommentBody(line, from: index + block.open.count, depth: 1, paintFrom: index, state: &state, painter: &painter) ?? line.count
        }
        for marker in spec.lineComments where line.has(marker, at: index) {
            if spec.commentNeedsBoundary, index > 0 {
                let before = line.at(index - 1)
                guard before.isSpace || Self.commandBoundaries.contains(before) else { continue }
            }
            painter.paint(index..<line.count, .comment)
            return line.count
        }
        if let style = spec.heredocs, let end = scanHeredocOperator(line, at: index, style: style, context: &context, painter: &painter) {
            return end
        }
        if spec.lifetimes, unit == ch("'"), line.at(index + 1).isIdentifierStart, line.at(index + 2) != ch("'") {
            let end = line.identifierEnd(from: index + 1)
            painter.paint(index..<end, .label)
            context.previous = .word("")
            return end
        }
        if let end = scanStringStart(line, at: index, prefix: nil, context: &context, state: &state, painter: &painter) {
            return end
        }
        if unit.isASCIIDigit || (unit == ch(".") && line.at(index + 1).isASCIIDigit) {
            let before = line.at(index - 1)
            if !(before.isIdentifierPart || spec.identifierExtra.contains(before)) {
                return scanNumber(line, at: index, context: &context, painter: &painter)
            }
        }
        if let end = scanVariable(line, at: index, context: &context, painter: &painter) { return end }
        if let end = scanAttribute(line, at: index, context: &context, painter: &painter) { return end }
        if spec.sigils, unit == ch("~"), let end = scanSigil(line, at: index, painter: &painter) {
            context.previous = .string
            return end
        }
        if spec.symbols, let end = scanSymbol(line, at: index, context: &context, painter: &painter) { return end }
        if spec.regexLiterals, unit == ch("/"), let end = scanRegex(line, at: index, context: &context, painter: &painter) { return end }
        if spec.jsxTags, unit == ch("<"), let end = scanJSXTag(line, at: index, context: &context, painter: &painter) { return end }
        if unit.isIdentifierStart || (context.expectCommand && Self.commandWordStarts.contains(unit)) {
            return scanWord(line, at: index, context: &context, state: &state, painter: &painter)
        }
        if spec.sectionHeaders, atLineStart, unit == ch("[") {
            let end = line.find(any: [ch("]")], from: index).map { line.at($0 + 1) == ch("]") ? $0 + 2 : $0 + 1 } ?? line.count
            painter.paint(index..<end, .type)
            context.previous = .punctuation(unit)
            return end
        }
        return scanPunctuation(line, at: index, context: &context)
    }

    private func scanPunctuation(_ line: Line, at index: Int, context: inout Context) -> Int {
        let unit = line.at(index)
        if spec.commandPosition {
            if unit == ch("(") { context.parenDepth += 1 } else if unit == ch(")") { context.parenDepth = max(0, context.parenDepth - 1) }
            if Self.commandBoundaries.contains(unit) || unit == ch("`") || unit == ch("!") {
                context.expectCommand = true
            } else if unit == ch(")"), context.casePattern {
                context.casePattern = false
                context.expectCommand = true
            } else if unit != ch("="), unit != ch("\\") {
                context.expectCommand = false   // `[ -f x ]`: `[` is the command, `-f` an argument
            }
        }
        context.previous = (unit == ch(")") || unit == ch("]") || unit == ch("}")) ? .closeBracket : .punctuation(unit)
        return index + 1
    }

    private func scanDirective(_ line: Line, at index: Int, context: inout Context, painter: inout LinePainter) -> Int {
        let wordEnd = line.identifierEnd(from: index + 1)
        painter.paint(index..<wordEnd, .attribute)
        context.previous = .keyword(line.string(index..<wordEnd))
        let word = line.string(index + 1..<wordEnd)
        if word == "include" || word == "import" || word == "include_next" {
            let start = line.skipSpaces(from: wordEnd)
            if line.at(start) == ch("<"), let close = line.find(any: [ch(">")], from: start) {
                painter.paint(start..<close + 1, .string)
                context.previous = .string
                return close + 1
            }
        }
        return wordEnd
    }

    private func finishLine(_ line: Line, context: Context, state: inout ScanState) {
        guard state == .none else { return }
        if let heredoc = context.pendingHeredoc {
            state = .heredoc(terminator: heredoc.terminator, indented: heredoc.indented)
        } else if spec.commandPosition, line.trailingBackslash {
            state = .continuation(command: context.expectCommand)
        }
    }

    // MARK: - Character classes

    /// Units that separate shell commands: the next word after one names a command.
    static let commandBoundaries: Set<UInt16> = [ch(";"), ch("|"), ch("&"), ch("("), ch("{")]
    /// Units a shell command word may start with besides identifier characters: `./run`, `/bin/x`, `~/x`.
    static let commandWordStarts: Set<UInt16> = [ch("."), ch("/"), ch("~")]
    /// Units a shell command word may continue with.
    static let commandWordParts: Set<UInt16> = [ch("-"), ch("."), ch("/"), ch("+"), ch(":"), ch("@"), ch("%"), ch(","), ch("~")]

    /// Index just past the bracket matching the one at `open`, or the line end.
    func matchingBracket(_ line: Line, from open: Int, open openUnit: UInt16, close closeUnit: UInt16) -> Int {
        var depth = 0
        var index = open
        while index < line.count {
            let unit = line.at(index)
            if unit == openUnit { depth += 1 } else if unit == closeUnit { depth -= 1; if depth == 0 { return index + 1 } }
            index += 1
        }
        return line.count
    }
}
