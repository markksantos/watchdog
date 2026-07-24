import SwiftUI
import AppKit
import Combine

/// Presentation preferences: theme, accent, menu bar glyph, gallery density.
///
/// Deliberately separate from `SettingsManager`, which owns capture behaviour. Nothing here
/// affects what Watchdog records or where it writes — it only changes how the app looks — so
/// keeping the two apart means a change to one can never disturb the other's stored keys.
final class AppearanceSettings: ObservableObject {
    static let shared = AppearanceSettings()

    @Published var theme: AppTheme {
        didSet {
            UserDefaults.standard.set(theme.rawValue, forKey: Keys.theme)
            applyTheme()
        }
    }

    @Published var accent: AccentChoice {
        didSet { UserDefaults.standard.set(accent.rawValue, forKey: Keys.accent) }
    }

    @Published var menuBarIcon: MenuBarIcon {
        didSet { UserDefaults.standard.set(menuBarIcon.rawValue, forKey: Keys.menuBarIcon) }
    }

    /// Show today's capture count next to the menu bar glyph.
    @Published var showMenuBarCount: Bool {
        didSet { UserDefaults.standard.set(showMenuBarCount, forKey: Keys.showMenuBarCount) }
    }

    /// Show the amber hint callouts in Preferences.
    @Published var showTips: Bool {
        didSet { UserDefaults.standard.set(showTips, forKey: Keys.showTips) }
    }

    /// Minimum width of a gallery thumbnail, in points.
    @Published var galleryThumbnailSize: Double {
        didSet { UserDefaults.standard.set(galleryThumbnailSize, forKey: Keys.galleryThumbnailSize) }
    }

    /// Resolved accent colour for tinting views.
    var accentColor: Color { accent.color }

    private enum Keys {
        static let theme = "appearance.theme"
        static let accent = "appearance.accent"
        static let menuBarIcon = "appearance.menuBarIcon"
        static let showMenuBarCount = "appearance.showMenuBarCount"
        static let showTips = "appearance.showTips"
        static let galleryThumbnailSize = "appearance.galleryThumbnailSize"
    }

    private init() {
        let defaults = UserDefaults.standard
        self.theme = AppTheme(rawValue: defaults.string(forKey: Keys.theme) ?? "") ?? .system
        self.accent = AccentChoice(rawValue: defaults.string(forKey: Keys.accent) ?? "") ?? .red
        self.menuBarIcon = MenuBarIcon(rawValue: defaults.string(forKey: Keys.menuBarIcon) ?? "") ?? .eye
        self.showMenuBarCount = defaults.object(forKey: Keys.showMenuBarCount) as? Bool ?? false
        self.showTips = defaults.object(forKey: Keys.showTips) as? Bool ?? true
        self.galleryThumbnailSize = defaults.object(forKey: Keys.galleryThumbnailSize) as? Double ?? 160
    }

    /// Applies the stored theme to the running app. Safe to call before the first window exists.
    func applyTheme() {
        NSApp?.appearance = theme.nsAppearance
    }

    func resetToDefaults() {
        theme = .system
        accent = .red
        menuBarIcon = .eye
        showMenuBarCount = false
        showTips = true
        galleryThumbnailSize = 160
    }
}
