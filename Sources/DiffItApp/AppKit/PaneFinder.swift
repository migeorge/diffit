import AppKit

/// One pane's `NSTextFinder`, its client adapter, and the match highlighting that follows the
/// finder's incremental results into the pane's text view.
@MainActor
final class PaneFinder {
    let finder = NSTextFinder()
    private let client: PaneFindClient
    private unowned let column: DiffColumnView
    private var observation: NSKeyValueObservation?

    init(column: DiffColumnView, container: FindBarContainer, reveal: @escaping (Int) -> Void) {
        self.column = column
        client = PaneFindClient(textView: column.textView)
        client.reveal = reveal
        finder.client = client
        finder.findBarContainer = container
        finder.isIncrementalSearchingEnabled = true
        // The pane highlights matches itself; the dimming overlay assumes a scroll view container.
        finder.incrementalSearchingShouldDimContentView = false
        observation = finder.observe(\.incrementalMatchRanges, options: [.new]) { [weak self] finder, _ in
            let ranges = finder.incrementalMatchRanges.map(\.rangeValue)
            Task { @MainActor [weak self] in self?.column.textView.matchRanges = ranges }
        }
    }

    func clearHighlights() {
        column.textView.matchRanges = []
        column.textView.currentMatch = nil
    }
}
