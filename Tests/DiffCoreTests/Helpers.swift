@testable import DiffCore

/// Deterministic SplitMix64 so property tests are reproducible.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// Replays `ops` over `old`; returns nil if the script is inconsistent, otherwise the reconstructed sequence.
func apply(_ ops: [DiffOp], old: [Int32], new: [Int32]) -> [Int32]? {
    var out: [Int32] = []
    var ai = 0, bi = 0
    for op in ops {
        switch op {
        case .equal(let o, let n):
            guard o == ai, n == bi, ai < old.count, bi < new.count, old[ai] == new[bi] else { return nil }
            out.append(new[bi]); ai += 1; bi += 1
        case .delete(let o):
            guard o == ai, ai < old.count else { return nil }
            ai += 1
        case .insert(let n):
            guard n == bi, bi < new.count else { return nil }
            out.append(new[bi]); bi += 1
        }
    }
    guard ai == old.count, bi == new.count else { return nil }
    return out
}

func editCost(_ ops: [DiffOp]) -> Int {
    ops.reduce(0) { if case .equal = $1 { return $0 } else { return $0 + 1 } }
}

/// Brute-force LCS length (DP) for small inputs.
func lcsLength(_ a: [Int32], _ b: [Int32]) -> Int {
    var dp = [[Int]](repeating: [Int](repeating: 0, count: b.count + 1), count: a.count + 1)
    for i in 0..<a.count {
        for j in 0..<b.count {
            dp[i + 1][j + 1] = a[i] == b[j] ? dp[i][j] + 1 : max(dp[i][j + 1], dp[i + 1][j])
        }
    }
    return dp[a.count][b.count]
}

func ids(_ s: String) -> [Int32] {
    s.unicodeScalars.map { Int32($0.value) }
}

func ids(_ lines: [String]) -> [Int32] {
    var interner = Interner<String>()
    return interner.intern(lines)
}
