import Foundation

/// Change-to-change navigation exposed by the live pair view so menu commands and the toolbar
/// can reach it.
@MainActor
protocol DiffNavigator: AnyObject {
    var changeBlockCount: Int { get }
    /// The block at the viewport's anchor line (a third of the way down), if any.
    var currentBlock: Int? { get }
    func scrollToChangeBlock(_ index: Int)
    func nextChange()
    func previousChange()
    /// Whether the current block is one end of a moved block.
    var currentBlockIsMove: Bool { get }
    /// Jumps from one end of the current block's move to the other.
    func jumpToMoveCounterpart()
}

/// Snapshot of the navigator for SwiftUI (the toolbar indicator).
struct ChangeNavigationState: Equatable {
    var current: Int?
    var count: Int
    var currentIsMove = false

    static let none = ChangeNavigationState(current: nil, count: 0)
}
