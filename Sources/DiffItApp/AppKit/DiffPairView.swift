import AppKit
import DiffCore

/// Side-by-side panes in a split view with mirrored vertical scrolling.
/// Original on the left, changed on the right.
final class DiffPairView: NSView, DiffNavigator, NSSplitViewDelegate {
    let oldColumn = DiffColumnView(side: .old)
    let newColumn = DiffColumnView(side: .new)
    private let splitView = NSSplitView()

    private(set) var changeBlocks: [Range<Int>] = []
    private(set) var currentBlock: Int?
    private var isSyncing = false

    // MARK: - Setup

    override init(frame: NSRect) {
        super.init(frame: frame)
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.autosaveName = "DiffPairSplit"
        splitView.delegate = self
        splitView.translatesAutoresizingMaskIntoConstraints = false
        splitView.addArrangedSubview(oldColumn)
        splitView.addArrangedSubview(newColumn)
        oldColumn.setContentHuggingPriority(.defaultLow, for: .horizontal)
        newColumn.setContentHuggingPriority(.defaultLow, for: .horizontal)
        addSubview(splitView)
        NSLayoutConstraint.activate([
            splitView.leadingAnchor.constraint(equalTo: leadingAnchor),
            splitView.trailingAnchor.constraint(equalTo: trailingAnchor),
            splitView.topAnchor.constraint(equalTo: topAnchor),
            splitView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        oldColumn.onScroll = { [weak self] column in self?.mirrorScroll(from: column) }
        newColumn.onScroll = { [weak self] column in self?.mirrorScroll(from: column) }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not supported") }

    override func layout() {
        super.layout()
        // Equal columns on first layout unless the divider was restored from the autosave.
        guard !didSetInitialDivider, splitView.frame.width > 0 else { return }
        didSetInitialDivider = true
        let saved = UserDefaults.standard.object(forKey: "NSSplitView Subview Frames DiffPairSplit") != nil
        if !saved || oldColumn.frame.width < Self.minimumColumnWidth {
            splitView.setPosition(splitView.frame.width / 2, ofDividerAt: 0)
        }
    }

    private var didSetInitialDivider = false
    private static let minimumColumnWidth: CGFloat = 160

    // MARK: - NSSplitViewDelegate

    func splitView(_ splitView: NSSplitView, canCollapseSubview subview: NSView) -> Bool { false }

    func splitView(_ splitView: NSSplitView, constrainMinCoordinate proposedMinimumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        max(proposedMinimumPosition, Self.minimumColumnWidth)
    }

    func splitView(_ splitView: NSSplitView, constrainMaxCoordinate proposedMaximumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        min(proposedMaximumPosition, splitView.frame.width - Self.minimumColumnWidth)
    }

    // MARK: - Content

    /// Rebuilds both panes. The first visible row is preserved across reloads (rows above may have shifted).
    func load(_ result: DiffResult?, style: DiffTextBuilder.Style, showChangeHatch: Bool, keepScroll: Bool) {
        let anchor = keepScroll ? newColumn.firstVisibleLine() : nil
        guard let result else {
            oldColumn.install(.empty(side: .old), font: style.font, showChangeHatch: showChangeHatch)
            newColumn.install(.empty(side: .new), font: style.font, showChangeHatch: showChangeHatch)
            changeBlocks = []
            currentBlock = nil
            return
        }
        oldColumn.install(DiffTextBuilder.build(result, side: .old, style: style), font: style.font, showChangeHatch: showChangeHatch)
        newColumn.install(DiffTextBuilder.build(result, side: .new, style: style), font: style.font, showChangeHatch: showChangeHatch)
        changeBlocks = result.changeBlocks
        if let currentBlock, !changeBlocks.indices.contains(currentBlock) { self.currentBlock = nil }
        if let anchor {
            let line = min(anchor.line, max(0, result.rows.count - 1))
            newColumn.scroll(toLine: line, offset: anchor.offset)
            mirrorScroll(from: newColumn)
        } else {
            newColumn.setVerticalOrigin(0)
            oldColumn.setVerticalOrigin(0)
        }
    }

    // MARK: - Scroll sync

    /// Vertical scrolling is mirrored by clip-view origin; horizontal scrolling stays independent per pane.
    private func mirrorScroll(from source: DiffColumnView) {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }
        let target = source === oldColumn ? newColumn : oldColumn
        target.setVerticalOrigin(source.clipView.bounds.origin.y)
    }

    // MARK: - DiffNavigator

    var changeBlockCount: Int { changeBlocks.count }

    func scrollToChangeBlock(_ index: Int) {
        guard changeBlocks.indices.contains(index) else { return }
        currentBlock = index
        let row = changeBlocks[index].lowerBound
        let offset = newColumn.clipView.bounds.height / 3
        newColumn.scroll(toLine: row, offset: offset)
        mirrorScroll(from: newColumn)
    }

    func nextChange() {
        guard !changeBlocks.isEmpty else { return }
        let firstVisible = newColumn.firstVisibleLine()?.line ?? 0
        // The first block starting after the row currently at the top (or below the current block).
        let floor = currentBlock.map { changeBlocks[$0].lowerBound } ?? firstVisible
        if let next = changeBlocks.firstIndex(where: { $0.lowerBound > floor }) {
            scrollToChangeBlock(next)
        }
    }

    func previousChange() {
        guard !changeBlocks.isEmpty else { return }
        let firstVisible = newColumn.firstVisibleLine()?.line ?? 0
        let ceiling = currentBlock.map { changeBlocks[$0].lowerBound } ?? firstVisible
        if let previous = changeBlocks.lastIndex(where: { $0.lowerBound < ceiling }) {
            scrollToChangeBlock(previous)
        }
    }
}
