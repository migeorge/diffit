import AppKit

/// Hosts the find bar above both panes. One bar for the pair (rather than the scroll views'
/// own) keeps the two clip views the same height, so the panes' scroll ranges stay equal.
///
/// Like `NSScrollView`, the container only stores the bar when the finder hands it over and
/// inserts it while tiling: `NSTextFinder` abandons its show sequence (no height update, no
/// `findBarVisible = true`) if the setter adds the bar to the view hierarchy.
final class FindBarContainer: NSView, NSTextFinderBarContainer {
    private var heightConstraint: NSLayoutConstraint?
    /// Reports the bar showing or hiding (the pane takes focus back when it hides).
    var onVisibilityChange: ((Bool) -> Void)?

    override init(frame: NSRect) {
        super.init(frame: frame)
        let height = heightAnchor.constraint(equalToConstant: 0)
        height.isActive = true
        heightConstraint = height
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not supported") }

    // MARK: - NSTextFinderBarContainer

    /// Set by whichever pane's finder is showing; the previous bar is dropped.
    var findBarView: NSView? {
        didSet {
            if let oldValue, oldValue !== findBarView { oldValue.removeFromSuperview() }
            retile()
        }
    }

    var isFindBarVisible = false {
        didSet {
            guard isFindBarVisible != oldValue else { return }
            retile()
            onVisibilityChange?(isFindBarVisible)
        }
    }

    func findBarViewDidChangeHeight() {
        retile()
    }

    /// Optional in the protocol, but some AppKit builds call it without checking
    /// (`-[... contentView]: unrecognized selector`, seen on macOS 27). It must be a method, not
    /// a computed property: only the method form answers the ObjC selector. nil: the panes
    /// highlight matches themselves, so there is nothing for the finder to dim.
    func contentView() -> NSView? { nil }

    /// The bar keeps its own height; the container takes that height while the bar is shown
    /// and collapses to nothing otherwise.
    private func retile() {
        guard let findBarView else {
            heightConstraint?.constant = 0
            return
        }
        let height = findBarView.frame.height
        if isFindBarVisible {
            heightConstraint?.constant = height
            if findBarView.superview !== self {
                findBarView.autoresizingMask = [.width]
                addSubview(findBarView)
            }
            findBarView.frame = NSRect(x: 0, y: 0, width: bounds.width, height: height)
            findBarView.isHidden = false
        } else {
            heightConstraint?.constant = 0
            findBarView.removeFromSuperview()
        }
    }

    override func layout() {
        super.layout()
        if let findBarView, findBarView.superview === self {
            findBarView.frame = NSRect(x: 0, y: 0, width: bounds.width, height: findBarView.frame.height)
        }
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        Theme.headerBackground.setFill()
        bounds.fill()
    }
}
