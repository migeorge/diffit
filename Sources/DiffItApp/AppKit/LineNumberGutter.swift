import AppKit

/// Line-number gutter drawn beside a pane's scroll view. It is a plain view rather than an
/// `NSRulerView`: on macOS 26 the scroll view lays its vertical ruler out as a full-width overlay
/// over the clip view, so anything opaque drawn in it hides the text.
/// Redraw is driven by the clip view's bounds notifications.
final class LineNumberGutter: NSView {
    private weak var textView: DiffTextView?
    private weak var clipView: NSClipView?
    private var numberFont: NSFont = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
    private(set) var thickness: CGFloat = 40

    private static let horizontalPadding: CGFloat = 6

    init(textView: DiffTextView, clipView: NSClipView) {
        self.textView = textView
        self.clipView = clipView
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not supported") }

    override var isFlipped: Bool { true }
    override var isOpaque: Bool { true }

    // MARK: - Content

    /// Sizes the gutter for the widest number and adopts the pane font's family at a smaller size.
    /// Returns true when the width changed.
    @discardableResult
    func contentDidChange(font: NSFont) -> Bool {
        let size = max(9, font.pointSize - 1)
        if let family = font.familyName,
           let f = NSFontManager.shared.font(withFamily: family, traits: [], weight: 3, size: size) {
            numberFont = f
        } else {
            numberFont = .monospacedDigitSystemFont(ofSize: size, weight: .light)
        }
        let digitWidth = DiffTextBuilder.zeroAdvance(numberFont)
        let digits = max(2, String(textView?.content?.maxSourceLineNumber ?? 0).count)
        let newThickness = ceil(CGFloat(digits) * digitWidth + Self.horizontalPadding * 2)
        needsDisplay = true
        guard newThickness != thickness else { return false }
        thickness = newThickness
        return true
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        Theme.paneBackground.setFill()
        dirtyRect.fill()
        Theme.gutterBackground.setFill()
        dirtyRect.fill()
        drawNumbers(in: dirtyRect)
        Theme.divider.setFill()
        NSRect(x: bounds.maxX - 1, y: dirtyRect.minY, width: 1, height: dirtyRect.height).fill()
    }

    private func drawNumbers(in rect: NSRect) {
        guard let textView, let clipView, let content = textView.content else { return }
        let attributes: [NSAttributedString.Key: Any] = [.font: numberFont, .foregroundColor: Theme.gutterText]
        // The gutter's top edge lines up with the clip view's top edge.
        let scrollY = clipView.bounds.minY
        let visible = NSRect(x: 0, y: rect.minY + scrollY, width: 1, height: rect.height)
        let right = bounds.maxX - Self.horizontalPadding - 1
        textView.enumerateLines(in: visible) { line, frame in
            let cell = NSRect(x: 0, y: frame.minY - scrollY, width: bounds.width - 1, height: frame.height)
            if let color = content.gutterBackground(line) {
                color.setFill()
                cell.fill()
            }
            guard let number = content.sourceLineNumbers[line] else { return }
            let label = String(number) as NSString
            let size = label.size(withAttributes: attributes)
            label.draw(at: NSPoint(x: right - size.width, y: cell.midY - size.height / 2), withAttributes: attributes)
        }
    }
}
