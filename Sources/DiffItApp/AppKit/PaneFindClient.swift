import AppKit

/// Adapts a pane's text view to `NSTextFinder`. `NSTextView` only serves as a find client
/// through its own `usesFindBar` machinery, which insists on the enclosing scroll view as the
/// bar's container; this adapter lets the pair share one bar instead.
final class PaneFindClient: NSObject, NSTextFinderClient {
    private unowned let textView: DiffTextView
    /// Asked to bring a row into view (the pair scrolls both panes together).
    var reveal: ((Int) -> Void)?

    init(textView: DiffTextView) {
        self.textView = textView
    }

    // MARK: - Text

    var string: String { textView.string }
    var isSelectable: Bool { true }
    var allowsMultipleSelection: Bool { false }
    var isEditable: Bool { false }

    // MARK: - Selection

    var firstSelectedRange: NSRange { textView.selectedRange() }

    var selectedRanges: [NSValue] {
        get { textView.selectedRanges }
        set {
            textView.selectedRanges = newValue
            textView.currentMatch = newValue.first?.rangeValue
        }
    }

    func scrollRangeToVisible(_ range: NSRange) {
        guard let row = textView.content?.lineIndex(forUTF16Offset: range.location) else { return }
        reveal?(row)
    }

    // MARK: - Geometry

    var visibleCharacterRanges: [NSValue] {
        [NSValue(range: textView.characterRange(forVisibleRect: textView.visibleRect))]
    }

    func rects(forCharacterRange range: NSRange) -> [NSValue]? {
        guard let layoutManager = textView.layoutManager, let container = textView.textContainer else { return nil }
        let glyphs = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        var rect = layoutManager.boundingRect(forGlyphRange: glyphs, in: container)
        rect.origin.x += textView.textContainerOrigin.x
        rect.origin.y += textView.textContainerOrigin.y
        return [NSValue(rect: rect)]
    }

    func contentView(at index: Int, effectiveCharacterRange outRange: NSRangePointer) -> NSView {
        outRange.pointee = NSRange(location: 0, length: (textView.string as NSString).length)
        return textView
    }

    /// The finder's match bubble: draw just those glyphs in the text view's coordinates.
    func drawCharacters(in range: NSRange, forContentView view: NSView) {
        guard let layoutManager = textView.layoutManager else { return }
        let glyphs = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        layoutManager.drawGlyphs(forGlyphRange: glyphs, at: textView.textContainerOrigin)
    }
}
