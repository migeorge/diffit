public struct DiffOptions: Sendable {
    /// Refine `.modified` rows with token-level highlights.
    public var intraLine = true
    /// Skip refinement when either line is longer than this (UTF-16 units).
    public var intraLineMaxLineLength = 2_000
    /// Above this highlighted fraction, drop the highlights (the whole line changed).
    public var intraLineMaxChangedFraction = 0.7
    /// D cap for the Myers fallback (memory ≈ D² Int32).
    public var myersMaxCost = 2_000

    public init() {}
}
