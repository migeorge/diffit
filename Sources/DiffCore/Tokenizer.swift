/// Splits a line (as UTF-16 code units) into identifier runs, whitespace runs and single punctuation units.
enum Tokenizer {
    struct Token: Equatable {
        /// UTF-16 offsets within the line.
        let range: Range<Int>
    }

    static func tokenize(_ units: [UInt16]) -> [Token] {
        var tokens: [Token] = []
        var i = 0
        while i < units.count {
            let start = i
            let unit = units[i]
            if isIdentifier(unit) {
                while i < units.count && isIdentifier(units[i]) { i += 1 }
            } else if isWhitespace(unit) {
                while i < units.count && isWhitespace(units[i]) { i += 1 }
            } else {
                i += 1
            }
            tokens.append(Token(range: start..<i))
        }
        return tokens
    }

    /// `[A-Za-z0-9_]` and anything non-ASCII (so CJK runs and surrogate pairs stay whole).
    private static func isIdentifier(_ u: UInt16) -> Bool {
        (u >= 0x30 && u <= 0x39) || (u >= 0x41 && u <= 0x5A) || (u >= 0x61 && u <= 0x7A) || u == 0x5F || u >= 0x80
    }

    private static func isWhitespace(_ u: UInt16) -> Bool {
        u == 0x20 || u == 0x09 || u == 0x0B || u == 0x0C || u == 0x0D
    }
}
