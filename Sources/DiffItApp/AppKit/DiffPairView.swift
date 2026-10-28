import AppKit
import DiffCore

/// Side-by-side panes in a split view with mirrored vertical scrolling.
/// Original on the left, changed on the right.
final class DiffPairView: NSView, DiffNavigator, NSSplitViewDelegate {
    let oldColumn = DiffColumnView(side: .old)
    let newColumn = DiffColumnView(side: .new)
    private let splitView = NSSplitView()
    private let markerStrip = ChangeMarkerStrip()

    private(set) var changeBlocks: [Range<Int>] = []
    private(set) var currentBlock: Int? {
        didSet {
            guard currentBlock != oldValue else { return }
            markerStrip.currentBlock = currentBlock
            publishNavigation()
        }
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
        markerStrip.translatesAutoresizingMaskIntoConstraints = false
        addSubview(splitView)
        addSubview(markerStrip)
        NSLayoutConstraint.activate([
            splitView.leadingAnchor.constraint(equalTo: leadingAnchor),
            splitView.trailingAnchor.constraint(equalTo: markerStrip.leadingAnchor),
            splitView.topAnchor.constraint(equalTo: topAnchor),
            splitView.bottomAnchor.constraint(equalTo: bottomAnchor),
            markerStrip.widthAnchor.constraint(equalToConstant: ChangeMarkerStrip.width),
            markerStrip.trailingAnchor.constraint(equalTo: trailingAnchor),
            markerStrip.topAnchor.constraint(equalTo: topAnchor),
            markerStrip.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        oldColumn.onScroll = { [weak self] column in self?.mirrorScroll(from: column) }
        newColumn.onScroll = { [weak self] column in
            self?.mirrorScroll(from: column)
            self?.updateCurrentBlock()
            self?.updateViewportIndicator()
        }
        markerStrip.onSelect = { [weak self] index in self?.scrollToChangeBlock(index) }
        for column in [oldColumn, newColumn] {
            column.textView.onHover = { [weak self] row in self?.setHoverRow(row) }
            column.textView.onRowClick = { [weak self] row in self?.focusBlock(containing: row) }
        }
    }

    // MARK: - Hover and click

    private func setHoverRow(_ row: Int?) {
        oldColumn.setHoverRow(row)
        newColumn.setHoverRow(row)
    }

    /// A click inside a change block makes it the current one without scrolling.
    private func focusBlock(containing row: Int) {
        if let index = changeBlocks.firstIndex(where: { $0.contains(row) }) {
            currentBlock = index
        }
    }

    private func updateViewportIndicator() {
        let clip = newColumn.clipView.bounds
        let height = max(newColumn.textView.frame.height, 1)
        markerStrip.viewport = (clip.minY / height)...min(1, clip.maxY / height)
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
    /// Move id of each row (nil for most), for counterpart navigation.
    private var moveIDOfRow: [Int?] = []

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
            moveIDOfRow = []
            currentBlock = nil
            markerStrip.blocks = []
            markerStrip.rowCount = 0
            publishNavigation()
            return
        }
        oldColumn.install(DiffTextBuilder.build(result, side: .old, style: style), font: style.font, showChangeHatch: showChangeHatch)
        newColumn.install(DiffTextBuilder.build(result, side: .new, style: style), font: style.font, showChangeHatch: showChangeHatch)
        changeBlocks = result.changeBlocks
        markerStrip.blocks = result.changeBlocks.map { ($0, Self.blockKind(result.rows[$0])) }
        markerStrip.rowCount = result.rows.count
        let mappedRow = anchor.flatMap { rowFollowingContent(from: $0.line, mapping: lineMapping, rows: result.rows) }
        newLineOfRow = result.rows.map(\.newLine)
        moveIDOfRow = result.rows.map(\.moveID)
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
        updateViewportIndicator()
        publishNavigation()
    }

    private static func blockKind(_ rows: ArraySlice<DiffRow>) -> ChangeBlockKind {
        var added = false, removed = false
        if rows.allSatisfy(\.isMoved) { return .moved }
        for row in rows {
            switch row.kind {
            case .added: added = true
            case .removed: removed = true
            case .modified: return .modified
            case .context: break
            }
            if added && removed { return .modified }
        }
        return added ? .added : .removed
    }

    // MARK: - Moves

    var currentBlockIsMove: Bool { currentMoveID != nil }

    private var currentMoveID: Int? {
        guard let currentBlock, changeBlocks.indices.contains(currentBlock) else { return nil }
        return changeBlocks[currentBlock].lazy.compactMap { self.moveIDOfRow[$0] }.first
    }

    func jumpToMoveCounterpart() {
        guard let currentBlock, let id = currentMoveID else { return }
        let here = changeBlocks[currentBlock]
        // The other end: a row with the same move id outside the current block.
        guard let row = moveIDOfRow.indices.first(where: { moveIDOfRow[$0] == id && !here.contains($0) }),
              let block = changeBlocks.firstIndex(where: { $0.contains(row) }) else { return }
        newColumn.scroll(toLine: row, offset: anchorOffset)
        mirrorScroll(from: newColumn)
        self.currentBlock = block
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
        onNavigationChange?(ChangeNavigationState(current: currentBlock, count: changeBlocks.count,
                                                  currentIsMove: currentBlockIsMove))
    }
}
