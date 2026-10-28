import AppKit

/// Kind of a whole change block, for colouring markers.
enum ChangeBlockKind {
    case added, removed, modified
}

/// A narrow strip beside the panes showing where every change block sits in the document,
/// the current block, and the part of the document that is on screen. Clicking jumps to the
/// nearest block.
final class ChangeMarkerStrip: NSView {
    static let width: CGFloat = 14

    var blocks: [(rows: Range<Int>, kind: ChangeBlockKind)] = [] { didSet { needsDisplay = true } }
    var rowCount = 0 { didSet { needsDisplay = true } }
    var currentBlock: Int? { didSet { if currentBlock != oldValue { needsDisplay = true } } }
    /// Visible fraction of the document (0...1), top to bottom.
    var viewport: ClosedRange<CGFloat> = 0...1 { didSet { if viewport != oldValue { needsDisplay = true } } }
    var onSelect: ((Int) -> Void)?

    override var isFlipped: Bool { true }

    private static let inset: CGFloat = 2
    private static let minMarkHeight: CGFloat = 2

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        Theme.paneBackground.setFill()
        bounds.fill()
        Theme.gutterBackground.setFill()
        bounds.fill()
        Theme.divider.setFill()
        NSRect(x: 0, y: 0, width: 1, height: bounds.height).fill()
        guard rowCount > 0 else { return }

        let track = trackRect
        for (index, block) in blocks.enumerated() {
            var mark = markRect(for: block.rows, in: track)
            let color: NSColor
            switch block.kind {
            case .added: color = Theme.markerAdded
            case .removed: color = Theme.markerRemoved
            case .modified: color = Theme.markerModified
            }
            if index == currentBlock {
                mark = mark.insetBy(dx: -1, dy: -1)
                Theme.markerCurrentOutline.setFill()
                mark.insetBy(dx: -1, dy: -1).fill()
            }
            color.setFill()
            mark.fill()
        }

        let top = track.minY + viewport.lowerBound * track.height
        let bottom = track.minY + viewport.upperBound * track.height
        Theme.viewportIndicator.setFill()
        NSRect(x: 1, y: top, width: bounds.width - 1, height: max(2, bottom - top)).fill()
    }

    private var trackRect: NSRect {
        NSRect(x: Self.inset + 1, y: Self.inset, width: bounds.width - Self.inset * 2 - 1, height: bounds.height - Self.inset * 2)
    }

    private func markRect(for rows: Range<Int>, in track: NSRect) -> NSRect {
        let scale = track.height / CGFloat(rowCount)
        let y = track.minY + CGFloat(rows.lowerBound) * scale
        let height = max(Self.minMarkHeight, CGFloat(rows.count) * scale)
        return NSRect(x: track.minX, y: y, width: track.width, height: height)
    }

    // MARK: - Mouse

    override func mouseDown(with event: NSEvent) {
        guard rowCount > 0, !blocks.isEmpty else { return }
        let y = convert(event.locationInWindow, from: nil).y
        let track = trackRect
        var best: (index: Int, distance: CGFloat)?
        for (index, block) in blocks.enumerated() {
            let mark = markRect(for: block.rows, in: track)
            let distance = y < mark.minY ? mark.minY - y : (y > mark.maxY ? y - mark.maxY : 0)
            if best == nil || distance < best!.distance { best = (index, distance) }
        }
        if let best { onSelect?(best.index) }
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }
}
