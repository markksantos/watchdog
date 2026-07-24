import SwiftUI
import AppKit

/// Watchdog's colour vocabulary.
///
/// Every colour in the app comes from here rather than from `.accentColor`, so that the
/// Appearance tab can retint the whole UI from one place. Names describe *meaning*, not hue —
/// `live` stays green even if the user picks a purple accent, because "the camera is running"
/// is not a branding decision.
enum WatchdogColor {
    /// Selected pills, primary calls to action. Overridden by the user's accent choice.
    static let primary = Color(red: 1.00, green: 0.23, blue: 0.19)   // #FF3B30
    /// Monitoring is active.
    static let live = Color(red: 0.20, green: 0.78, blue: 0.35)      // #34C759
    /// Trial countdown, expiring subscription, recoverable problems.
    static let warn = Color(red: 1.00, green: 0.58, blue: 0.00)      // #FF9500
    /// Switches and sliders.
    static let toggle = Color(red: 0.00, green: 0.48, blue: 1.00)    // #007AFF
    /// Hint callouts.
    static let tip = Color(red: 1.00, green: 0.80, blue: 0.00)       // #FFCC00
    /// Pro locks and badges.
    static let pro = Color(red: 0.69, green: 0.32, blue: 0.87)       // #AF52DE

    /// Surface behind a settings card. Adapts to light/dark automatically.
    static let card = Color(nsColor: .controlBackgroundColor)
    /// Hairline around a card.
    static let cardBorder = Color(nsColor: .separatorColor)
    /// Page background behind the cards.
    static let canvas = Color(nsColor: .windowBackgroundColor)
}

// MARK: - Accent choice

/// The accent colours offered in Appearance. `system` follows the user's macOS accent.
enum AccentChoice: String, CaseIterable, Codable, Identifiable {
    case red, blue, green, purple, orange, graphite, system

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .red: return "Red"
        case .blue: return "Blue"
        case .green: return "Green"
        case .purple: return "Purple"
        case .orange: return "Orange"
        case .graphite: return "Graphite"
        case .system: return "Match System"
        }
    }

    var color: Color {
        switch self {
        case .red: return WatchdogColor.primary
        case .blue: return Color(red: 0.00, green: 0.48, blue: 1.00)
        case .green: return Color(red: 0.16, green: 0.68, blue: 0.38)
        case .purple: return WatchdogColor.pro
        case .orange: return Color(red: 1.00, green: 0.45, blue: 0.10)
        case .graphite: return Color(red: 0.40, green: 0.42, blue: 0.45)
        case .system: return Color(nsColor: .controlAccentColor)
        }
    }
}

// MARK: - Theme

/// Light / dark / follow-the-system.
enum AppTheme: String, CaseIterable, Codable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "Auto"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }

    /// `nil` means "inherit from the system", which is what `NSApp.appearance = nil` does.
    var nsAppearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }
}

// MARK: - Menu bar icon

/// Which glyph sits in the menu bar. Purely cosmetic — the item is always present, because
/// hiding it would be both a lie and an App Review problem.
enum MenuBarIcon: String, CaseIterable, Codable, Identifiable {
    case eye, shield, camera, dot

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .eye: return "Eye"
        case .shield: return "Shield"
        case .camera: return "Camera"
        case .dot: return "Dot"
        }
    }

    /// Symbol shown while monitoring is off.
    var idleSymbol: String {
        switch self {
        case .eye: return "eye"
        case .shield: return "shield"
        case .camera: return "camera"
        case .dot: return "circle"
        }
    }

    /// Symbol shown while monitoring is on.
    var activeSymbol: String {
        switch self {
        case .eye: return "eye.fill"
        case .shield: return "shield.fill"
        case .camera: return "camera.fill"
        case .dot: return "circle.fill"
        }
    }
}

// MARK: - Metrics

/// Sizes shared between SwiftUI views and the AppKit code that hosts them.
///
/// The popover size in particular lived in two places — `PopoverView.frame` and
/// `NSPopover.contentSize` — which is how the detection-mode picker ended up clipped when
/// only one of them was considered. One constant now feeds both.
enum WatchdogMetrics {
    static let popoverWidth: CGFloat = 360
    /// Sized for the idle layout. Monitoring adds a Capture Now button and free accounts add
    /// an upgrade prompt; the content scrolls rather than clipping when it grows.
    static let popoverHeight: CGFloat = 440

    static let preferencesWidth: CGFloat = 660
    static let preferencesHeight: CGFloat = 680

    static let cardCornerRadius: CGFloat = 10
    static let pillCornerRadius: CGFloat = 8
}
