import AppKit

/// One pane: a line-number gutter beside a scroll view holding a `DiffTextView`.
final class DiffColumnView: NSView {
    let side: DiffSide
    let scrollView = NSScrollView()
    /// Created before the gutter: the gutter keeps a weak reference to the clip view, so it must
    /// be the one the scroll view keeps, not the default one that this replaces.
    private let clip = PaneClipView()
    let textView = DiffTextView.make()
    let gutter: LineNumberGutter
    private var gutterWidth: NSLayoutConstraint?
    private let placeholderLabel = NSTextField(labelWithString: "")

    /// Called with the clip view's new bounds origin after the user (or sync) scrolls this pane.
    var onScroll: ((DiffColumnView) -> Void)?

    /// The widest document of the pair, so both panes need a horizontal scroller together or not
    /// at all: a legacy (non-overlay) horizontal scroller in one pane only would shorten that
    /// pane's clip view and give the two panes different scroll ranges.
    var minimumDocumentWidth: CGFloat = 0 {
        didSet { if minimumDocumentWidth != oldValue { fitTextViewToClip() } }
    }

    private var observers: [NSObjectProtocol] = []

    // MARK: - Setup

    init(side: DiffSide) {
        self.side = side
        gutter = LineNumberGutter(textView: textView, clipView: clip)
        super.init(frame: .zero)

        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        // The text view always covers the clip view (see fitTextViewToClip), so no scroll view
        // background is needed; on macOS 26 enabling it adds a visual-effect view.
        scrollView.drawsBackground = false
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.contentView = clip
        scrollView.documentView = textView
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        gutter.translatesAutoresizingMaskIntoConstraints = false

        placeholderLabel.font = .systemFont(ofSize: 15)
        placeholderLabel.textColor = .secondaryLabelColor
        placeholderLabel.alignment = .center
        placeholderLabel.isHidden = true
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false

        addSubview(gutter)
        addSubview(scrollView)
        addSubview(placeholderLabel)
        let width = gutter.widthAnchor.constraint(equalToConstant: gutter.thickness)
        gutterWidth = width
        NSLayoutConstraint.activate([
            gutter.leadingAnchor.constraint(equalTo: leadingAnchor),
            gutter.topAnchor.constraint(equalTo: topAnchor),
            gutter.bottomAnchor.constraint(equalTo: bottomAnchor),
            width,
            scrollView.leadingAnchor.constraint(equalTo: gutter.trailingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            placeholderLabel.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            placeholderLabel.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor),
        ])

        clip.postsBoundsChangedNotifications = true
        clip.postsFrameChangedNotifications = true
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: NSView.boundsDidChangeNotification, object: clip, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.gutter.needsDisplay = true
                self.onScroll?(self)
            }
        })
        observers.append(center.addObserver(forName: NSView.frameDidChangeNotification, object: clip, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.fitTextViewToClip() }
        })
        fitTextViewToClip()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not supported") }

    deinit {
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
    }

    // MARK: - Content

    /// Shown centred over the pane when this side has no file at all; rows are then plain filler.
    var placeholder: String? {
        didSet {
            placeholderLabel.stringValue = placeholder ?? ""
            placeholderLabel.isHidden = placeholder == nil
        }
    }

    func install(_ content: DiffPaneContent, font: NSFont, showChangeHatch: Bool) {
        textView.showChangeHatch = showChangeHatch && placeholder == nil
        textView.install(content, font: font)
        if gutter.contentDidChange(font: font) {
            gutterWidth?.constant = gutter.thickness
        }
        fitTextViewToClip()
    }

    /// The text view is at least as large as the clip view (so row tints span the pane and short
    /// documents still paint the background) and as large as the whole document.
    private func fitTextViewToClip() {
        let clip = scrollView.contentView.bounds.size
        guard clip.width > 0 else { return }
        let content = textView.contentSize
        let size = NSSize(width: max(clip.width, content.width, minimumDocumentWidth),
                          height: max(clip.height, content.height))
        if textView.frame.size != size { textView.setFrameSize(size) }
    }

    /// Highlights `row` (view-wide hover) in the text view and the gutter.
    func setHoverRow(_ row: Int?) {
        guard textView.hoverRow != row else { return }
        textView.hoverRow = row
        gutter.needsDisplay = true
    }

    // MARK: - Scrolling

    var clipView: NSClipView { scrollView.contentView }

    /// First visible line and how far its top sits below the clip view's top edge
    /// (negative when the row is partly scrolled past). Feed it back to `scroll(toLine:offset:)`.
    func firstVisibleLine() -> (line: Int, offset: CGFloat)? {
        let top = clipView.bounds.minY
        guard let line = textView.row(atViewY: top) else { return nil }
        return (line, textView.rowTop(line) - top)
    }

    /// Scrolls vertically so that `line`'s top sits `offset` points below the clip view's top.
    func scroll(toLine line: Int, offset: CGFloat) {
        setVerticalOrigin(textView.rowTop(line) - offset)
    }

    func setVerticalOrigin(_ y: CGFloat) {
        let clip = clipView
        let maxY = max(0, (textView.frame.height) - clip.bounds.height)
        let target = NSPoint(x: clip.bounds.origin.x, y: min(max(0, y), maxY))
        guard target != clip.bounds.origin else { return }
        clip.scroll(to: target)
        scrollView.reflectScrolledClipView(clip)
    }
}
