/// Token-level refinement of a `.modified` row.
enum IntraLineDiff {
    struct Highlights: Equatable {
        var old: [Range<Int>] = []
        var new: [Range<Int>] = []
    }

    /// Myers cost cap for token diffs; above it the row keeps whole-line colouring only.
    private static let maxCost = 256

    static func highlights(old: String, new: String, options: DiffOptions) -> Highlights {
        let oldUnits = Array(old.utf16), newUnits = Array(new.utf16)
        guard oldUnits.count <= options.intraLineMaxLineLength,
              newUnits.count <= options.intraLineMaxLineLength else { return Highlights() }

        let oldTokens = Tokenizer.tokenize(oldUnits), newTokens = Tokenizer.tokenize(newUnits)
        var interner = Interner<ArraySlice<UInt16>>()
        let a = oldTokens.map { interner.intern(oldUnits[$0.range]) }
        let b = newTokens.map { interner.intern(newUnits[$0.range]) }
        guard let ops = Myers.diff(a[...], b[...], maxD: maxCost) else { return Highlights() }

        var result = Highlights()
        for op in ops {
            switch op {
            case .equal: break
            case .delete(let i): append(oldTokens[i].range, to: &result.old)
            case .insert(let j): append(newTokens[j].range, to: &result.new)
            }
        }

        if fraction(result.old, of: oldUnits.count) > options.intraLineMaxChangedFraction
            || fraction(result.new, of: newUnits.count) > options.intraLineMaxChangedFraction {
            return Highlights()
        }
        return result
    }

    /// Appends a range, merging it into the previous one when they touch or overlap.
    private static func append(_ range: Range<Int>, to ranges: inout [Range<Int>]) {
        if let last = ranges.last, range.lowerBound <= last.upperBound {
            ranges[ranges.count - 1] = last.lowerBound..<max(last.upperBound, range.upperBound)
        } else {
            ranges.append(range)
        }
    }

    private static func fraction(_ ranges: [Range<Int>], of length: Int) -> Double {
        guard length > 0 else { return 0 }
        return Double(ranges.reduce(0) { $0 + $1.count }) / Double(length)
    }
}
