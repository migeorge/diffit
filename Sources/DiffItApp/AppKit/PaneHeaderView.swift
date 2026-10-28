import AppKit

/// The bar over one pane: the side's label on the left, its change count (or a spinner while the
/// diff loads) on the right. Lives in AppKit so it can be pinned to its column's edges and follow
/// the split view's divider.
final class PaneHeaderView: NSView {
    static let height: CGFloat = 26

    struct Content: Equatable {
        var label: String
        var count: Int
        var isLoading: Bool
    }

    private let label = NSTextField(labelWithString: "")
    private let count = NSTextField(labelWithString: "")
    private let spinner = NSProgressIndicator()

    /// `sign` prefixes the count ("+" / "−"); `tint` colours it.
    init(sign: String, tint: NSColor) {
        self.sign = sign
        super.init(frame: .zero)
        let font = NSFont.systemFont(ofSize: 12)
        label.font = font
        label.textColor = .secondaryLabelColor
        label.lineBreakMode = .byTruncatingMiddle
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        count.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        count.textColor = tint
        count.alignment = .right
        spinner.style = .spinning
        spinner.controlSize = .mini
        spinner.isDisplayedWhenStopped = false
        for view in [label, count, spinner] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            count.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            count.centerYAnchor.constraint(equalTo: centerYAnchor),
            count.leadingAnchor.constraint(greaterThanOrEqualTo: label.trailingAnchor, constant: 8),
            spinner.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            spinner.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not supported") }

    private let sign: String

    // MARK: - Content

    func update(_ content: Content) {
        label.stringValue = content.label
        count.stringValue = content.count > 0 ? sign + String(content.count) : ""
        count.isHidden = content.isLoading
        if content.isLoading { spinner.startAnimation(nil) } else { spinner.stopAnimation(nil) }
    }

    // MARK: - Drawing

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        Theme.headerBackground.setFill()
        bounds.fill()
        Theme.divider.setFill()
        NSRect(x: 0, y: bounds.maxY - 1, width: bounds.width, height: 1).fill()
    }
}

/// The 1 pt rule between the two headers, pinned to the split view's divider.
final class HeaderDividerView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        Theme.headerBackground.setFill()
        bounds.fill()
        Theme.divider.setFill()
        NSRect(x: 0, y: 4, width: bounds.width, height: bounds.height - 8).fill()
    }
}
