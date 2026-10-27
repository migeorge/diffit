enum LineSplitter {
    struct Result: Equatable {
        var lines: [String]
        var missingFinalNewline: Bool
    }

    /// Splits on `\n` or `\r\n`; a lone `\r` stays inside its line. Empty text → zero lines.
    /// Works on UTF-8 bytes rather than `Character`s so large files split quickly.
    static func split(_ text: String) -> Result {
        var lines: [String] = []
        let utf8 = text.utf8
        var start = utf8.startIndex
        var i = start
        while i != utf8.endIndex {
            if utf8[i] == 0x0A {
                var end = i
                if end > start, utf8[utf8.index(before: end)] == 0x0D {
                    end = utf8.index(before: end)
                }
                lines.append(String(text[start..<end]))
                i = utf8.index(after: i)
                start = i
            } else {
                i = utf8.index(after: i)
            }
        }
        let missingFinalNewline = start != utf8.endIndex
        if missingFinalNewline {
            lines.append(String(text[start..<utf8.endIndex]))
        }
        return Result(lines: lines, missingFinalNewline: missingFinalNewline)
    }
}
