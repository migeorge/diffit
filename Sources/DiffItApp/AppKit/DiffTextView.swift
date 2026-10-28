import AppKit

/// Read-only text view that tints whole rows by diff kind.
///
/// Deliberately TextKit 1 (`usingTextLayoutManager: false`): TextKit 2 re-lays out tens of
/// thousands of fragments after any far viewport jump (about a second on a 50k-line file).
/// The whole document is laid out once in `install` (about 0.3 s for 50k single-height rows), after
/// which scrolling anywhere is free and the view's geometry is final. Lazy (non-contiguous) layout
/// was tried first and rejected: NSTextView keeps resizing itself and scrolling the clip view as
/// layout progresses, which fought the arithmetic row geometry and left panes blank after a reload.
/// See DECISIONS.md.
final class DiffTextView: NSTextView {
    var content: DiffPaneContent? {
        didSet { needsDisplay = true }
    }
    var showChangeHatch = true {
        didSet { needsDisplay = true }
    }
    /// Row under the pointer in either pane; drawn with `Theme.hoverRow`.
    var hoverRow: Int? {
        didSet {
            guard hoverRow != oldValue else { return }
            for row in [oldValue, hoverRow].compactMap({ $0 }) { setNeedsDisplay(rowRect(row)) }
        }
    }
    /// Rows of the current change block, outlined in the accent colour.
    var currentBlock: Range<Int>? {
        didSet {
            guard currentBlock != oldValue else { return }
            for block in [oldValue, currentBlock].compactMap({ $0 }) { setNeedsDisplay(blockRect(block)) }
        }
    }
    /// Pointer moved over a row (nil when it left the pane).
    var onHover: ((Int?) -> Void)?
    /// Primary click landed on a row (selection handling continues as usual).
    var onRowClick: ((Int) -> Void)?
    /// The view became first responder (the pair tracks which pane find should target).
    var onFocus: (() -> Void)?
    private var hoverTrackingArea: NSTrackingArea?

    // MARK: - Find

    /// Incremental find matches, sorted by location, and the one the finder last selected.
    /// Highlighted with temporary attributes over the visible rows only (`refreshMatchHighlights`).
    var matchRanges: [NSRange] = [] {
        didSet { refreshMatchHighlights() }
    }
    var currentMatch: NSRange? {
        didSet { if currentMatch != oldValue { refreshMatchHighlights() } }
    }
    private var highlightedRange = NSRange(location: 0, length: 0)

    /// Character range of the rows intersecting `rect` (view coordinates).
    func characterRange(forVisibleRect rect: NSRect) -> NSRange {
        guard let content, content.lineCount > 0 else { return NSRange(location: 0, length: 0) }
        var first = Int.max, last = -1
        enumerateLines(in: rect) { line, _ in first = min(first, line); last = max(last, line) }
        guard first <= last else { return NSRange(location: 0, length: 0) }
        let start = content.lineStarts[first]
        let end = last + 1 < content.lineCount ? content.lineStarts[last + 1] : (string as NSString).length
        return NSRange(location: start, length: max(0, end - start))
    }

    /// Re-applies match highlights for the rows now on screen. Called on scroll while a find is
    /// active; a screen's worth of temporary attributes is cheap and needs no layout.
    func refreshMatchHighlights() {
        guard let layoutManager else { return }
        if highlightedRange.length > 0 {
            layoutManager.removeTemporaryAttribute(.backgroundColor, forCharacterRange: highlightedRange)
            highlightedRange = NSRange(location: 0, length: 0)
        }
        guard !matchRanges.isEmpty || currentMatch != nil else { return }
        let visible = characterRange(forVisibleRect: visibleRect.insetBy(dx: 0, dy: -visibleRect.height))
        guard visible.length > 0 else { return }
        highlightedRange = visible
        // First match ending inside the visible range (ranges are sorted by location).
        var low = 0, high = matchRanges.count
        while low < high {
            let mid = (low + high) / 2
            if NSMaxRange(matchRanges[mid]) < visible.location { low = mid + 1 } else { high = mid }
        }
        let limit = NSMaxRange(visible)
        for range in matchRanges[low...] {
            if range.location >= limit { break }
            let clipped = NSIntersectionRange(range, visible)
            guard clipped.length > 0 else { continue }
            layoutManager.addTemporaryAttribute(.backgroundColor, value: Theme.findMatch, forCharacterRange: clipped)
        }
        if let currentMatch, currentMatch.length > 0 {
            let clipped = NSIntersectionRange(currentMatch, visible)
            if clipped.length > 0 {
                layoutManager.addTemporaryAttribute(.backgroundColor, value: Theme.findCurrentMatch, forCharacterRange: clipped)
            }
        }
    }

    // MARK: - Setup

    static func make() -> DiffTextView {
        let tv = DiffTextView(usingTextLayoutManager: false)
        tv.layoutManager?.allowsNonContiguousLayout = false
        tv.isEditable = false
        tv.isSelectable = true
        tv.isRichText = false
        tv.allowsUndo = false
        tv.usesFontPanel = false
        tv.usesFindBar = false    // the pair shares one find bar; see PaneFindClient
        tv.drawsBackground = true
        tv.backgroundColor = Theme.paneBackground
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.isAutomaticTextReplacementEnabled = false
        tv.isAutomaticSpellingCorrectionEnabled = false
        tv.isAutomaticDataDetectionEnabled = false
        tv.isAutomaticLinkDetectionEnabled = false
        tv.isAutomaticTextCompletionEnabled = false
        tv.isContinuousSpellCheckingEnabled = false
        tv.isGrammarCheckingEnabled = false
        tv.smartInsertDeleteEnabled = false
        // The view never resizes itself: DiffColumnView sets its frame from the known row count
        // and measured line width. NSTextView's own resizing as layout progresses made the clip
        // view jump during far scrolls.
        tv.isVerticallyResizable = false
        tv.isHorizontallyResizable = false
        tv.autoresizingMask = []
        tv.textContainer?.widthTracksTextView = false
        tv.textContainer?.heightTracksTextView = false
        tv.textContainer?.size = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        tv.textContainer?.lineFragmentPadding = 8
        tv.textContainerInset = NSSize(width: 0, height: 4)
        tv.registerForDraggedTypes([])    // view-only: nothing can be dropped in
        return tv
    }

    // MARK: - Content

    /// Replaces the whole document and lays all of it out, so later scrolls never trigger layout.
    func install(_ content: DiffPaneContent, font: NSFont) {
        self.content = content
        self.font = font
        highlightedRange = NSRange(location: 0, length: 0)   // the old text's attributes went with it
        matchRanges = []
        currentMatch = nil
        textStorage?.setAttributedString(content.text)
        if let layoutManager, let textContainer {
            layoutManager.ensureLayout(for: textContainer)
        }
        setSelectedRange(NSRange(location: 0, length: 0))
        needsDisplay = true
    }

    // MARK: - Geometry

    /// Exact size of the whole document, from the row count and the measured widest line.
    var contentSize: NSSize {
        guard let content else { return .zero }
        let padding = textContainer?.lineFragmentPadding ?? 0
        return NSSize(width: ceil(content.textWidth + padding * 2 + textContainerInset.width * 2),
                      height: textContainerInset.height * 2 + CGFloat(content.lineCount) * content.lineHeight)
    }

    /// Top y (view coordinates) of a row.
    func rowTop(_ line: Int) -> CGFloat {
        textContainerInset.height + CGFloat(line) * (content?.lineHeight ?? 1)
    }

    /// Full-width frame of a row in view coordinates.
    func rowRect(_ line: Int) -> NSRect {
        NSRect(x: bounds.minX, y: rowTop(line), width: bounds.width, height: content?.lineHeight ?? 1)
    }

    /// Frame of a run of rows, from the top of the first to the bottom of the last.
    func blockRect(_ block: Range<Int>) -> NSRect {
        guard !block.isEmpty else { return .zero }
        return rowRect(block.lowerBound).union(rowRect(block.upperBound - 1))
    }

    /// The row at a y position in view coordinates, clamped to the document.
    func row(atViewY y: CGFloat) -> Int? {
        guard let content, content.lineCount > 0 else { return nil }
        let raw = Int(floor((y - textContainerInset.height) / content.lineHeight))
        return min(max(raw, 0), content.lineCount - 1)
    }

    /// Calls `body` with the row index and view-coordinate frame of every row intersecting `rect`.
    /// Pure arithmetic: rows have a fixed height, so no layout is forced to tint the background.
    func enumerateLines(in rect: NSRect, _ body: (Int, NSRect) -> Void) {
        guard let content, content.lineCount > 0 else { return }
        let height = content.lineHeight, inset = textContainerInset.height
        let first = max(0, Int(floor((rect.minY - inset) / height)))
        let last = min(content.lineCount - 1, Int(ceil((rect.maxY - inset) / height)))
        guard first <= last else { return }
        for line in first...last {
            body(line, NSRect(x: 0, y: inset + CGFloat(line) * height, width: bounds.width, height: height))
        }
    }

    // MARK: - Mouse

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverTrackingArea { removeTrackingArea(hoverTrackingArea) }
        let area = NSTrackingArea(rect: .zero,
                                  options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
                                  owner: self, userInfo: nil)
        addTrackingArea(area)
        hoverTrackingArea = area
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        onHover?(row(atViewY: convert(event.locationInWindow, from: nil).y))
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        onHover?(nil)
    }

    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        if accepted { onFocus?() }
        return accepted
    }

    override func mouseDown(with event: NSEvent) {
        if let row = row(atViewY: convert(event.locationInWindow, from: nil).y) { onRowClick?(row) }
        super.mouseDown(with: event)
    }

    // MARK: - Drawing

    override func drawBackground(in rect: NSRect) {
        super.drawBackground(in: rect)
        guard let content else { return }
        let hatch = showChangeHatch
        enumerateLines(in: rect) { line, frame in
            guard let color = content.rowBackground(line) else { return }
            let row = NSRect(x: bounds.minX, y: frame.minY, width: bounds.width, height: frame.height)
            color.setFill()
            row.fill()
            if hatch, content.isFiller[line] {
                Self.drawHatch(in: row)
            }
        }
        if let hoverRow, hoverRow < content.lineCount {
            let row = rowRect(hoverRow)
            if row.intersects(rect) {
                Theme.hoverRow.setFill()
                row.fill()
            }
        }
        if let currentBlock {
            Self.drawBlockOutline(blockRect(currentBlock), in: rect)
        }
    }

    /// Rules along the top and bottom edges of the current block (the gutter continues them).
    static func drawBlockOutline(_ block: NSRect, in rect: NSRect) {
        guard block.intersects(rect) else { return }
        Theme.currentBlockOutline.setFill()
        NSRect(x: block.minX, y: block.minY, width: block.width, height: 1).fill()
        NSRect(x: block.minX, y: block.maxY - 1, width: block.width, height: 1).fill()
    }

    /// 1-px diagonal hatch over a filler row.
    static func drawHatch(in rect: NSRect) {
        let step: CGFloat = 8
        let path = NSBezierPath()
        path.lineWidth = 1
        var x = rect.minX - rect.height
        while x < rect.maxX {
            path.move(to: NSPoint(x: x, y: rect.maxY))
            path.line(to: NSPoint(x: x + rect.height, y: rect.minY))
            x += step
        }
        NSGraphicsContext.saveGraphicsState()
        rect.clip()
        Theme.fillerHatch.setStroke()
        path.stroke()
        NSGraphicsContext.restoreGraphicsState()
    }
}
