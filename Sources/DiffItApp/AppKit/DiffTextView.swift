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
    /// Pointer moved over a row (nil when it left the pane).
    var onHover: ((Int?) -> Void)?
    /// Primary click landed on a row (selection handling continues as usual).
    var onRowClick: ((Int) -> Void)?
    private var hoverTrackingArea: NSTrackingArea?

    // MARK: - Setup

    static func make() -> DiffTextView {
        let tv = DiffTextView(usingTextLayoutManager: false)
        tv.layoutManager?.allowsNonContiguousLayout = false
        tv.isEditable = false
        tv.isSelectable = true
        tv.isRichText = false
        tv.allowsUndo = false
        tv.usesFontPanel = false
        tv.usesFindBar = true
        tv.isIncrementalSearchingEnabled = true
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
