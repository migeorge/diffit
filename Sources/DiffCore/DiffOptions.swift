public struct DiffOptions: Sendable {
    /// Refine `.modified` rows with token-level highlights.
    public var intraLine = true
    /// Skip refinement when either line is longer than this (UTF-16 units).
    public var intraLineMaxLineLength = 2_000
    /// Above this highlighted fraction, drop the highlights (the whole line changed).
    public var intraLineMaxChangedFraction = 0.7
    /// D cap for the Myers fallback (memory ≈ D² Int32).
    public var myersMaxCost = 2_000
    /// Pair removed blocks with identical inserted blocks elsewhere and mark both as moved.
    public var detectMoves = true
    /// A move must carry at least this many non-whitespace characters in total …
    public var moveMinimumCharacters = 40
    /// … and only a line with at least this many non-whitespace characters may start one.
    public var moveMinimumLineCharacters = 4

    public init() {}
}
