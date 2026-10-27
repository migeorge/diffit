/// Maps distinct values to dense `Int32` ids so equality becomes an integer comparison.
/// One interner is shared by both sides of a diff.
struct Interner<Key: Hashable> {
    private var ids: [Key: Int32] = [:]

    var count: Int { ids.count }

    mutating func intern(_ key: Key) -> Int32 {
        if let id = ids[key] { return id }
        let id = Int32(ids.count)
        ids[key] = id
        return id
    }

    mutating func intern(_ keys: [Key]) -> [Int32] {
        var out: [Int32] = []
        out.reserveCapacity(keys.count)
        for key in keys { out.append(intern(key)) }
        return out
    }
}
