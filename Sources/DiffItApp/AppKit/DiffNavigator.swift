import Foundation

/// Change-to-change navigation exposed by the live pair view so menu commands can reach it.
@MainActor
protocol DiffNavigator: AnyObject {
    var changeBlockCount: Int { get }
    var currentBlock: Int? { get }
    func scrollToChangeBlock(_ index: Int)
    func nextChange()
    func previousChange()
}
