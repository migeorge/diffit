import AppKit

/// Read-only text view that tints whole rows by diff kind.
///
/// Deliberately TextKit 1 (`usingTextLayoutManager: false`) with non-contiguous layout: TextKit 2
/// re-lays out tens of thousands of fragments after any far viewport jump (about a second on a
/// 50k-line file), while TextKit 1 lays out only the visible glyph range. See DECISIONS.md.
final class DiffTextView: NSTextView {
    var content: DiffPaneContent? {
        didSet { needsDisplay = true }
    }
    var showChangeHatch = true {
        didSet { needsDisplay = true }
    }

    // MARK: - Setup

    static func make() -> DiffTextView {
        let tv = DiffTextView(usingTextLayoutManager: false)
        tv.layoutManager?.allowsNonContiguousLayout = true
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
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = true
        tv.autoresizingMask = []          // no width tracking: long lines scroll horizontally
        tv.minSize = .zero
        tv.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        tv.textContainer?.widthTracksTextView = false
        tv.textContainer?.heightTracksTextView = false
        tv.textContainer?.size = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        tv.textContainer?.lineFragmentPadding = 8
        tv.textContainerInset = NSSize(width: 0, height: 4)
        tv.registerForDraggedTypes([])    // R7: nothing can be dropped in
        return tv
    }

    // MARK: - Content

    /// Replaces the whole document.
    func install(_ content: DiffPaneContent, font: NSFont) {
        self.content = content
        self.font = font
        textStorage?.setAttributedString(content.text)
        setSelectedRange(NSRange(location: 0, length: 0))
        needsDisplay = true
    }

    // MARK: - Geometry

    // Rows have a fixed height (pinned by the paragraph style), so positions are plain arithmetic
    // and never force layout. Asking the layout manager would also be unreliable far from the
    // visible region, where only estimated geometry exists.

    /// Top y (view coordinates) of a row.
    func rowTop(_ line: Int) -> CGFloat {
        textContainerInset.height + CGFloat(line) * (content?.lineHeight ?? 1)
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
