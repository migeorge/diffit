import Foundation

/// A byte pattern to look for in a line, as UTF-16 units.
typealias Pattern = [UInt16]

func pattern(_ text: String) -> Pattern { Array(text.utf16) }

/// The UTF-16 unit for an ASCII character, for readable comparisons.
@inline(__always) func ch(_ scalar: Unicode.Scalar) -> UInt16 { UInt16(truncatingIfNeeded: scalar.value) }

extension UInt16 {
    var isASCIIDigit: Bool { self >= 48 && self <= 57 }
    var isASCIIUpper: Bool { self >= 65 && self <= 90 }
    var isASCIILower: Bool { self >= 97 && self <= 122 }
    var isASCIILetter: Bool { isASCIIUpper || isASCIILower }
    var isHexDigit: Bool { isASCIIDigit || (self >= 65 && self <= 70) || (self >= 97 && self <= 102) }
    /// Letters, `_` and anything outside ASCII (so non-Latin identifiers hold together).
    var isIdentifierStart: Bool { isASCIILetter || self == 95 || self > 127 }
    var isIdentifierPart: Bool { isIdentifierStart || isASCIIDigit }
    var isSpace: Bool { self == 32 || self == 9 }
    var asciiLowercased: UInt16 { isASCIIUpper ? self + 32 : self }
}

/// One source line as UTF-16 units with bounds-safe lookups (`at` returns 0 past either end).
struct Line {
    let units: [UInt16]
    var count: Int { units.count }

    init(_ text: String) { units = Array(text.utf16) }
    init(units: [UInt16]) { self.units = units }

    @inline(__always) func at(_ index: Int) -> UInt16 {
        index >= 0 && index < units.count ? units[index] : 0
    }

    func has(_ pattern: Pattern, at index: Int) -> Bool {
        guard index >= 0, index + pattern.count <= units.count else { return false }
        for (offset, unit) in pattern.enumerated() where units[index + offset] != unit { return false }
        return true
    }

    func hasCaseInsensitive(_ pattern: Pattern, at index: Int) -> Bool {
        guard index >= 0, index + pattern.count <= units.count else { return false }
        for (offset, unit) in pattern.enumerated() where units[index + offset].asciiLowercased != unit.asciiLowercased { return false }
        return true
    }

    /// Index of the first occurrence of `pattern` at or after `start`.
    func find(_ pattern: Pattern, from start: Int) -> Int? {
        guard !pattern.isEmpty, start >= 0 else { return nil }
        var index = start
        while index + pattern.count <= units.count {
            if has(pattern, at: index) { return index }
            index += 1
        }
        return nil
    }

    func string(_ range: Range<Int>) -> String {
        let lower = max(0, range.lowerBound), upper = min(units.count, range.upperBound)
        guard lower < upper else { return "" }
        return String(utf16CodeUnits: Array(units[lower..<upper]), count: upper - lower)
    }

    /// Index of the first non-blank unit at or after `start` (`count` if none).
    func skipSpaces(from start: Int) -> Int {
        var index = start
        while index < units.count, units[index].isSpace { index += 1 }
        return index
    }

    /// End of the identifier that starts at `start`.
    func identifierEnd(from start: Int, extra: Set<UInt16> = []) -> Int {
        var index = start
        while index < units.count, units[index].isIdentifierPart || extra.contains(units[index]) { index += 1 }
        return index
    }

    /// Index of the first unit in `set` at or after `start`.
    func find(any set: Set<UInt16>, from start: Int) -> Int? {
        var index = max(0, start)
        while index < units.count {
            if set.contains(units[index]) { return index }
            index += 1
        }
        return nil
    }

    var isBlank: Bool { units.allSatisfy(\.isSpace) }
    var indentation: Int { skipSpaces(from: 0) }
    var trailingBackslash: Bool {
        var backslashes = 0
        var index = units.count - 1
        while index >= 0, units[index] == ch("\\") { backslashes += 1; index -= 1 }
        return backslashes % 2 == 1
    }
}
