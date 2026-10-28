/// HTML, XML and PHP: tags, attributes, entities and comments, with `<script>`, `<style>` and
/// `<?php … ?>` regions handed to the matching code scanner.
struct MarkupScanner: LineScanner {
    enum Flavor { case html, xml, php }
    let flavor: Flavor
    private let phpCode = CodeScanner(.php)

    init(_ flavor: Flavor) { self.flavor = flavor }

    func scan(_ line: Line, from start: Int, stopAt: Pattern?, state: inout ScanState, painter: inout LinePainter) -> Int {
        var index = start
        while index < line.count {
            switch state {
            case .blockComment:
                guard let close = line.find(Self.commentClose, from: index) else {
                    painter.paint(index..<line.count, .comment)
                    return line.count
                }
                painter.paint(index..<close + 3, .comment)
                index = close + 3
                state = .none
            case .rawBlock(let close, let kind):
                let closePattern = pattern(close)
                guard let end = line.find(closePattern, from: index) else {
                    painter.paint(index..<line.count, kind)
                    return line.count
                }
                painter.paint(index..<end + closePattern.count, kind)
                index = end + closePattern.count
                state = .none
            case .embedded(let language, let close, var inner):
                let closePattern = pattern(close)
                let stop = embeddedScanner(for: language).scan(line, from: index, stopAt: closePattern, state: &inner, painter: &painter)
                guard stop < line.count else {
                    state = .embedded(language, close: close, inner: inner)
                    return line.count
                }
                painter.paint(stop..<stop + closePattern.count, language == .php ? .attribute : .tag)
                index = stop + closePattern.count
                state = .none
            case .insideTag(let name):
                index = scanAttributes(line, from: index, tag: name, state: &state, painter: &painter)
            default:
                index = scanText(line, from: index, state: &state, painter: &painter)
            }
        }
        return line.count
    }

    private static let commentOpen = pattern("<!--")
    private static let commentClose = pattern("-->")
    private static let cdataOpen = pattern("<![CDATA[")

    private func embeddedScanner(for language: SyntaxLanguage) -> any LineScanner {
        language == .php ? phpCode : language.scanner
    }

    // MARK: - Text and tag openers

    private func scanText(_ line: Line, from start: Int, state: inout ScanState, painter: inout LinePainter) -> Int {
        var index = start
        while index < line.count {
            let unit = line.at(index)
            if unit == ch("&"), let end = entityEnd(line, from: index) {
                painter.paint(index..<end, .escape)
                index = end
                continue
            }
            guard unit == ch("<") else { index += 1; continue }
            if line.has(Self.commentOpen, at: index) {
                painter.paint(index..<index + 4, .comment)
                state = .blockComment(depth: 1)
                return index + 4
            }
            if line.has(Self.cdataOpen, at: index) {
                painter.paint(index..<index + 9, .string)
                state = .rawBlock(close: "]]>", kind: .string)
                return index + 9
            }
            if flavor == .php, line.has(pattern("<?php"), at: index) || line.has(pattern("<?="), at: index) {
                let end = line.at(index + 2) == ch("=") ? index + 3 : index + 5
                painter.paint(index..<end, .attribute)
                state = .embedded(.php, close: "?>", inner: .none)
                return end
            }
            if line.at(index + 1) == ch("?") {
                painter.paint(index..<index + 2, .attribute)
                state = .rawBlock(close: "?>", kind: .attribute)
                return index + 2
            }
            if line.at(index + 1) == ch("!") {
                let end = line.find(any: [ch(">")], from: index).map { $0 + 1 } ?? line.count
                painter.paint(index..<end, .attribute)
                return end
            }
            var nameStart = index + 1
            if line.at(nameStart) == ch("/") { nameStart += 1 }
            guard line.at(nameStart).isIdentifierStart else { index += 1; continue }
            let nameEnd = line.identifierEnd(from: nameStart, extra: Self.nameUnits)
            painter.paint(index..<nameEnd, .tag)
            let name = line.string(nameStart..<nameEnd).lowercased()
            let closing = line.at(index + 1) == ch("/")
            state = .insideTag(name: closing ? "/" + name : name)
            return nameEnd
        }
        return line.count
    }

    private static let nameUnits: Set<UInt16> = [ch("-"), ch(":"), ch(".")]

    private func entityEnd(_ line: Line, from start: Int) -> Int? {
        var cursor = start + 1
        if line.at(cursor) == ch("#") { cursor += 1 }
        let begin = cursor
        while line.at(cursor).isIdentifierPart { cursor += 1 }
        guard cursor > begin, line.at(cursor) == ch(";") else { return nil }
        return cursor + 1
    }

    // MARK: - Attributes

    private func scanAttributes(_ line: Line, from start: Int, tag: String, state: inout ScanState, painter: inout LinePainter) -> Int {
        var index = start
        while index < line.count {
            let unit = line.at(index)
            if unit.isSpace { index += 1; continue }
            if unit == ch(">") || (unit == ch("/") && line.at(index + 1) == ch(">")) || (unit == ch("?") && line.at(index + 1) == ch(">")) {
                let end = unit == ch(">") ? index + 1 : index + 2
                painter.paint(index..<end, .tag)
                state = .none
                if flavor == .html, unit == ch(">") {
                    if tag == "script" { state = .embedded(.javascript, close: "</script>", inner: .none) }
                    if tag == "style" { state = .embedded(.css, close: "</style>", inner: .none) }
                }
                return end
            }
            if unit == ch("\"") || unit == ch("'") {
                let close = line.find(any: [unit], from: index + 1).map { $0 + 1 } ?? line.count
                painter.paint(index..<close, .string)
                index = close
                continue
            }
            if unit.isIdentifierStart || unit == ch("@") || unit == ch(":") || unit == ch("#") {
                let end = line.identifierEnd(from: index + 1, extra: Self.nameUnits)
                painter.paint(index..<end, .attribute)
                index = end
                continue
            }
            index += 1
        }
        state = .insideTag(name: tag)
        return line.count
    }
}
