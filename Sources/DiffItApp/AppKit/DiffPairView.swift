import AppKit
import DiffCore

/// Side-by-side panes in a split view with mirrored vertical scrolling.
/// Original on the left, changed on the right.
final class DiffPairView: NSView, DiffNavigator, NSSplitViewDelegate {
    let oldColumn = DiffColumnView(side: .old)
    let newColumn = DiffColumnView(side: .new)
    private let splitView = NSSplitView()

    private(set) var changeBlocks: [Range<Int>] = []
    private(set) var currentBlock: Int? {
        didSet { if currentBlock != oldValue { publishNavigation() } }
    }
    private var isSyncing = false

    /// Reports block count / current block whenever either changes (toolbar indicator).
    var onNavigationChange: ((ChangeNavigationState) -> Void)?

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
        newColumn.onScroll = { [weak self] column in
            self?.mirrorScroll(from: column)
            self?.updateCurrentBlock()
        }
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

    /// Labels for sides that have no file (added / deleted); nil shows the rows as usual.
    func setPlaceholders(old: String?, new: String?) {
        oldColumn.placeholder = old
        newColumn.placeholder = new
    }

    /// New-side line index of each row of the last loaded result, for content-based scroll restore.
    private var newLineOfRow: [Int?] = []

    /// Rebuilds both panes. With `keepScroll` the row at the top stays in view: by content when
    /// `lineMapping` says where the previous generation's lines went, otherwise by row index.
    func load(_ result: DiffResult?, style: DiffTextBuilder.Style, showChangeHatch: Bool, keepScroll: Bool,
              lineMapping: [Int]? = nil) {
        let anchor = keepScroll ? newColumn.firstVisibleLine() : nil
        guard let result else {
            oldColumn.install(.empty(side: .old), font: style.font, showChangeHatch: showChangeHatch)
            newColumn.install(.empty(side: .new), font: style.font, showChangeHatch: showChangeHatch)
            changeBlocks = []
            newLineOfRow = []
            currentBlock = nil
            publishNavigation()
            return
        }
        oldColumn.install(DiffTextBuilder.build(result, side: .old, style: style), font: style.font, showChangeHatch: showChangeHatch)
        newColumn.install(DiffTextBuilder.build(result, side: .new, style: style), font: style.font, showChangeHatch: showChangeHatch)
        changeBlocks = result.changeBlocks
        let mappedRow = anchor.flatMap { rowFollowingContent(from: $0.line, mapping: lineMapping, rows: result.rows) }
        newLineOfRow = result.rows.map(\.newLine)
        if let currentBlock, !changeBlocks.indices.contains(currentBlock) { self.currentBlock = nil }
        if let anchor {
            let line = mappedRow ?? min(anchor.line, max(0, result.rows.count - 1))
            newColumn.scroll(toLine: line, offset: anchor.offset)
            mirrorScroll(from: newColumn)
            updateCurrentBlock()
        } else {
            newColumn.setVerticalOrigin(0)
            oldColumn.setVerticalOrigin(0)
            currentBlock = nil
        }
        publishNavigation()
    }

    /// The row in `rows` showing the same new-side content as previous row `row`, via `mapping`.
    /// Falls back to the next surviving line when that line itself was removed.
    private func rowFollowingContent(from row: Int, mapping: [Int]?, rows: [DiffRow]) -> Int? {
        guard let mapping, !newLineOfRow.isEmpty else { return nil }
        var previousRow = row
        while previousRow < newLineOfRow.count, newLineOfRow[previousRow] == nil { previousRow += 1 }
        guard previousRow < newLineOfRow.count, var line = newLineOfRow[previousRow] else { return nil }
        let rowsSkipped = previousRow - row
        var target = -1
        while line < mapping.count {
            if mapping[line] >= 0 { target = mapping[line]; break }
            line += 1
        }
        guard target >= 0 else { return nil }
        // New-side lines increase monotonically along rows; binary search over rows with a line.
        var low = 0, high = rows.count - 1
        while low <= high {
            let mid = (low + high) / 2
            var probe = mid
            while probe <= high, rows[probe].newLine == nil { probe += 1 }
            guard probe <= high, let value = rows[probe].newLine else { high = mid - 1; continue }
            if value == target { return max(0, probe - rowsSkipped) }
            if value < target { low = probe + 1 } else { high = mid - 1 }
        }
        return nil
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

    /// Navigation parks a block's first row this far below the top of the viewport.
    private var anchorOffset: CGFloat { newColumn.clipView.bounds.height / 3 }

    func scrollToChangeBlock(_ index: Int) {
        guard changeBlocks.indices.contains(index) else { return }
        newColumn.scroll(toLine: changeBlocks[index].lowerBound, offset: anchorOffset)
        mirrorScroll(from: newColumn)
        currentBlock = index
    }

    /// Keeps the current block while it stays on screen; once it scrolls away, the current block
    /// becomes the first visible block at or below the anchor line, or none.
    private func updateCurrentBlock() {
        let clip = newColumn.clipView.bounds
        guard !changeBlocks.isEmpty,
              let firstVisible = newColumn.textView.row(atViewY: clip.minY),
              let anchorRow = newColumn.textView.row(atViewY: clip.minY + anchorOffset),
              let lastVisible = newColumn.textView.row(atViewY: clip.maxY - 1) else {
            currentBlock = nil
            return
        }
        if let currentBlock, changeBlocks.indices.contains(currentBlock),
           changeBlocks[currentBlock].overlaps(firstVisible...lastVisible) {
            return
        }
        currentBlock = changeBlocks.firstIndex { $0.upperBound > anchorRow && $0.lowerBound <= lastVisible }
    }

    func nextChange() {
        guard !changeBlocks.isEmpty else { return }
        let firstVisible = newColumn.firstVisibleLine()?.line ?? 0
        // The block after the current one, or the first block after the row at the top.
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

    private func publishNavigation() {
        onNavigationChange?(ChangeNavigationState(current: currentBlock, count: changeBlocks.count))
    }
}
