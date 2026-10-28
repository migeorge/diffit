import AppKit
import DiffCore

/// Colour tokens for the diff panes. Every colour is appearance-aware.
enum Theme {
    static let paneBackground = NSColor.textBackgroundColor
    static let gutterText = NSColor.secondaryLabelColor
    static let divider = NSColor.separatorColor

    static let removedLine = dynamic(light: hex(0xFFE9E9), dark: rgba(255, 90, 90, 0.16))
    static let removedStrong = dynamic(light: hex(0xFFB8B8), dark: rgba(255, 90, 90, 0.42))
    static let addedLine = dynamic(light: hex(0xE6FFEA), dark: rgba(80, 220, 120, 0.16))
    static let addedStrong = dynamic(light: hex(0xABF2BA), dark: rgba(80, 220, 120, 0.40))
    static let filler = dynamic(light: hex(0xF2F2F4), dark: rgba(255, 255, 255, 0.04))
    static let fillerHatch = dynamic(light: rgba(0, 0, 0, 0.06), dark: rgba(255, 255, 255, 0.06))
    static let gutterBackground = dynamic(light: hex(0xF7F7F8), dark: rgba(255, 255, 255, 0.03))

    // Gutter cells use a lighter version of the row tint.
    static let removedGutter = dynamic(light: hex(0xFFF2F2), dark: rgba(255, 90, 90, 0.10))
    static let addedGutter = dynamic(light: hex(0xF0FFF3), dark: rgba(80, 220, 120, 0.10))

    /// Full-width background for one row on one side; nil for untinted context rows.
    static func rowBackground(_ kind: RowKind, side: DiffSide, isFiller: Bool) -> NSColor? {
        if isFiller { return filler }
        switch (kind, side) {
        case (.context, _): return nil
        case (.removed, _), (.modified, .old): return removedLine
        case (.added, _), (.modified, .new): return addedLine
        }
    }

    /// Gutter background for one row; nil for untinted context rows.
    static func gutterRowBackground(_ kind: RowKind, side: DiffSide, isFiller: Bool) -> NSColor? {
        if isFiller { return filler }
        switch (kind, side) {
        case (.context, _): return nil
        case (.removed, _), (.modified, .old): return removedGutter
        case (.added, _), (.modified, .new): return addedGutter
        }
    }

    /// Intra-line highlight for `.modified` rows.
    static func strongHighlight(side: DiffSide) -> NSColor {
        side == .old ? removedStrong : addedStrong
    }

    // MARK: - Helpers

    static func dynamic(light: NSColor, dark: NSColor) -> NSColor {
        NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        }
    }

    private static func hex(_ value: UInt32) -> NSColor {
        NSColor(srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
                green: CGFloat((value >> 8) & 0xFF) / 255,
                blue: CGFloat(value & 0xFF) / 255,
                alpha: 1)
    }

    private static func rgba(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat) -> NSColor {
        NSColor(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: a)
    }
}

/// Which pane a piece of content belongs to.
enum DiffSide: Sendable {
    case old, new
}
