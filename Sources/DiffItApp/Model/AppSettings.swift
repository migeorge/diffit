import AppKit
import Foundation

/// User preferences, persisted in `UserDefaults`. Views key off `version` to know when to re-render.
@MainActor @Observable
final class AppSettings {
    static let shared = AppSettings()

    static let fontSizeRange: ClosedRange<Double> = 8...32
    static let tabWidths = [2, 4, 8]

    /// Empty ⇒ the system monospaced font.
    var fontFamily: String { didSet { changed(Keys.fontFamily, fontFamily) } }
    /// Callers keep it within `fontSizeRange`; clamping here would re-enter the observable setter.
    var fontSize: Double { didSet { changed(Keys.fontSize, fontSize) } }
    var tabWidth: Int { didSet { changed(Keys.tabWidth, tabWidth) } }
    var intraLineHighlights: Bool { didSet { changed(Keys.intraLineHighlights, intraLineHighlights) } }
    /// Changes the diff itself (not just its rendering); `AppModel` reloads on change.
    var detectMoves: Bool { didSet { changed(Keys.detectMoves, detectMoves) } }
    var showChangeHatch: Bool { didSet { changed(Keys.showChangeHatch, showChangeHatch) } }
    /// Reserved: the panes clip long lines in v1, so the toggle is shown disabled.
    var wrapLines: Bool { didSet { changed(Keys.wrapLines, wrapLines) } }

    /// Bumps whenever any setting changes.
    private(set) var version = 0

    private enum Keys {
        static let fontFamily = "fontFamily"
        static let fontSize = "fontSize"
        static let tabWidth = "tabWidth"
        static let intraLineHighlights = "intraLineHighlights"
        static let detectMoves = "detectMoves"
        static let showChangeHatch = "showChangeHatch"
        static let wrapLines = "wrapLines"
    }

    private init() {
        let defaults = UserDefaults.standard
        fontFamily = defaults.string(forKey: Keys.fontFamily) ?? ""
        let size = defaults.double(forKey: Keys.fontSize)
        fontSize = Self.fontSizeRange.contains(size) ? size : 12
        let tab = defaults.integer(forKey: Keys.tabWidth)
        tabWidth = Self.tabWidths.contains(tab) ? tab : 4
        intraLineHighlights = defaults.object(forKey: Keys.intraLineHighlights) as? Bool ?? true
        detectMoves = defaults.object(forKey: Keys.detectMoves) as? Bool ?? true
        showChangeHatch = defaults.object(forKey: Keys.showChangeHatch) as? Bool ?? true
        wrapLines = false
    }

    // MARK: - Derived

    /// `NSFont(name:size:)` fails for many family names; the font manager resolves families.
    var font: NSFont {
        if !fontFamily.isEmpty,
           let font = NSFontManager.shared.font(withFamily: fontFamily, traits: [], weight: 5, size: fontSize) {
            return font
        }
        return .monospacedSystemFont(ofSize: fontSize, weight: .regular)
    }

    var canIncreaseFontSize: Bool { fontSize < Self.fontSizeRange.upperBound }
    var canDecreaseFontSize: Bool { fontSize > Self.fontSizeRange.lowerBound }

    func increaseFontSize() { setFontSize(fontSize + 1) }
    func decreaseFontSize() { setFontSize(fontSize - 1) }

    func setFontSize(_ size: Double) {
        let clamped = min(max(size, Self.fontSizeRange.lowerBound), Self.fontSizeRange.upperBound)
        if clamped != fontSize { fontSize = clamped }
    }

    /// Installed font families that resolve to a fixed-pitch face, for the font picker.
    static let monospacedFamilies: [String] = {
        let manager = NSFontManager.shared
        return manager.availableFontFamilies
            .filter { !$0.hasPrefix(".") }
            .filter { manager.font(withFamily: $0, traits: [], weight: 5, size: 12)?.isFixedPitch == true }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }()

    // MARK: - Private

    private func changed(_ key: String, _ value: Any) {
        UserDefaults.standard.set(value, forKey: key)
        version += 1
    }
}
