import AppKit
import Foundation

/// User preferences, persisted in `UserDefaults`. Views key off `version` to know when to re-render.
/// Phase 4 carries only what the panes need; Phase 6 adds the remaining settings and the UI.
@MainActor @Observable
final class AppSettings {
    static let shared = AppSettings()

    /// Empty ⇒ the system monospaced font.
    var fontFamily: String { didSet { changed(Keys.fontFamily, fontFamily) } }
    var fontSize: Double { didSet { fontSize = min(max(fontSize, 8), 32); changed(Keys.fontSize, fontSize) } }
    var tabWidth: Int { didSet { changed(Keys.tabWidth, tabWidth) } }
    var showChangeHatch: Bool { didSet { changed(Keys.showChangeHatch, showChangeHatch) } }

    /// Bumps whenever any setting changes.
    private(set) var version = 0

    private enum Keys {
        static let fontFamily = "fontFamily"
        static let fontSize = "fontSize"
        static let tabWidth = "tabWidth"
        static let showChangeHatch = "showChangeHatch"
    }

    private init() {
        let defaults = UserDefaults.standard
        fontFamily = defaults.string(forKey: Keys.fontFamily) ?? ""
        let size = defaults.double(forKey: Keys.fontSize)
        fontSize = size > 0 ? size : 12
        let tab = defaults.integer(forKey: Keys.tabWidth)
        tabWidth = tab > 0 ? tab : 4
        showChangeHatch = defaults.object(forKey: Keys.showChangeHatch) as? Bool ?? true
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

    func increaseFontSize() { fontSize += 1 }
    func decreaseFontSize() { fontSize -= 1 }

    // MARK: - Private

    private func changed(_ key: String, _ value: Any) {
        UserDefaults.standard.set(value, forKey: key)
        version += 1
    }
}
