/// One step of an edit script. Indices refer to the respective line (or token) arrays.
public enum DiffOp: Equatable, Sendable {
    case equal(old: Int, new: Int)
    case delete(old: Int)
    case insert(new: Int)
}
