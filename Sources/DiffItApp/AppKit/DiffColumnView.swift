import AppKit

/// One pane: a scroll view holding a `DiffTextView` with a `LineNumberRuler`.
final class DiffColumnView: NSView {
    let side: DiffSide
    let scrollView = NSScrollView()
    let textView = DiffTextView.make()
    let gutter: LineNumberGutter
    private var gutterWidth: NSLayoutConstraint?

    /// Called with the clip view's new bounds origin after the user (or sync) scrolls this pane.
    var onScroll: ((DiffColumnView) -> Void)?

    private var observers: [NSObjectProtocol] = []

    // MARK: - Setup

    init(side: DiffSide) {
        self.side = side
        gutter = LineNumberGutter(textView: textView, clipView: scrollView.contentView)
        super.init(frame: .zero)

        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        // The text view always covers the clip view (see fitTextViewToClip), so no scroll view
        // background is needed; on macOS 26 enabling it adds a visual-effect view.
        scrollView.drawsBackground = false
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.documentView = textView
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        gutter.translatesAutoresizingMaskIntoConstraints = false

        addSubview(gutter)
        addSubview(scrollView)
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
        ])

        let clip = scrollView.contentView
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

    func install(_ content: DiffPaneContent, font: NSFont, showChangeHatch: Bool) {
        textView.showChangeHatch = showChangeHatch
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
        let size = NSSize(width: max(clip.width, content.width), height: max(clip.height, content.height))
        if textView.frame.size != size { textView.setFrameSize(size) }
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
