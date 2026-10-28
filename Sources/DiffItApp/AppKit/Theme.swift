import AppKit
import SyntaxHighlight
import DiffCore

/// Colour tokens for the diff panes. Every colour is appearance-aware.
enum Theme {
    static let paneBackground = NSColor.textBackgroundColor
    static let gutterText = NSColor.secondaryLabelColor
    static let divider = NSColor.separatorColor
    static let headerBackground = NSColor.windowBackgroundColor
    /// Outline of the current change block in the panes (rules above and below, bar in the gutter).
    static let currentBlockOutline = NSColor.controlAccentColor

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

    // MARK: Syntax

    /// Token colours after Xcode's default theme, chosen to stay legible over the diff tints.
    static func syntaxColor(_ kind: TokenKind) -> NSColor {
        switch kind {
        case .keyword, .tag, .heading: return dynamic(light: hex(0x9B2393), dark: hex(0xFC5FA3))
        case .function: return dynamic(light: hex(0x326D74), dark: hex(0x67B7A4))
        case .type: return dynamic(light: hex(0x0B4F79), dark: hex(0x5DD8FF))
        case .string, .codeSpan: return dynamic(light: hex(0xC41A16), dark: hex(0xFC6A5D))
        case .escape, .attribute: return dynamic(light: hex(0x947100), dark: hex(0xE0A050))
        case .comment: return dynamic(light: hex(0x6B7A88), dark: hex(0x7F8C98))
        case .number, .constant, .label: return dynamic(light: hex(0x1C00CF), dark: hex(0xD0BF69))
        case .property: return dynamic(light: hex(0x6C36A5), dark: hex(0xA167E6))
        case .link: return dynamic(light: hex(0x0E5FD8), dark: hex(0x6699FF))
        case .strong, .emphasis: return .labelColor
        }
    }

    /// Lines that moved elsewhere unchanged: one hue on both sides.
    static let movedLine = dynamic(light: hex(0xECE8FF), dark: rgba(150, 130, 255, 0.18))
    static let movedGutter = dynamic(light: hex(0xF3F0FF), dark: rgba(150, 130, 255, 0.11))
    static let markerMoved = dynamic(light: hex(0x8A70E0), dark: hex(0xA48CFF))

    /// Find bar matches; the current one is stronger.
    static let findMatch = dynamic(light: rgba(255, 214, 0, 0.45), dark: rgba(255, 214, 0, 0.30))
    static let findCurrentMatch = dynamic(light: rgba(255, 140, 0, 0.75), dark: rgba(255, 150, 20, 0.65))

    /// Row under the pointer, drawn over the diff tint in both panes.
    static let hoverRow = dynamic(light: rgba(0, 0, 0, 0.05), dark: rgba(255, 255, 255, 0.06))

    /// Change marker strip.
    static let markerAdded = dynamic(light: hex(0x3DBE63), dark: hex(0x50DC78))
    static let markerRemoved = dynamic(light: hex(0xE0504F), dark: hex(0xFF5A5A))
    static let markerModified = dynamic(light: hex(0xE0A030), dark: hex(0xF0B848))
    static let markerCurrentOutline = NSColor.controlAccentColor
    static let viewportIndicator = dynamic(light: rgba(0, 0, 0, 0.07), dark: rgba(255, 255, 255, 0.10))

    /// Full-width background for one row on one side; nil for untinted context rows.
    static func rowBackground(_ kind: RowKind, side: DiffSide, isFiller: Bool, isMoved: Bool = false) -> NSColor? {
        if isFiller { return filler }
        if isMoved { return movedLine }
        switch (kind, side) {
        case (.context, _): return nil
        case (.removed, _), (.modified, .old): return removedLine
        case (.added, _), (.modified, .new): return addedLine
        }
    }

    /// Gutter background for one row; nil for untinted context rows.
    static func gutterRowBackground(_ kind: RowKind, side: DiffSide, isFiller: Bool, isMoved: Bool = false) -> NSColor? {
        if isFiller { return filler }
        if isMoved { return movedGutter }
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
