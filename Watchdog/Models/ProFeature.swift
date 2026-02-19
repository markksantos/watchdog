import Foundation

enum ProFeature: String, CaseIterable {
    case unlimitedHistory = "Unlimited History"
    case detectionScheduling = "Detection Scheduling"
    case videoRecording = "Video Recording"
    case webhookAlerts = "Webhook Alerts"
    case advancedPDFReports = "Advanced PDF Reports"
    case statsDashboard = "Stats Dashboard"
    case alarmSiren = "Alarm Siren"
    case flashAlert = "Flash Alert"
    case stealthMode = "Stealth Mode"
    case autoLock = "Auto-Lock"

    var icon: String {
        switch self {
        case .unlimitedHistory: return "infinity"
        case .detectionScheduling: return "clock.badge.checkmark"
        case .videoRecording: return "video.fill"
        case .webhookAlerts: return "bell.and.waves.left.and.right"
        case .advancedPDFReports: return "doc.richtext.fill"
        case .statsDashboard: return "chart.bar.fill"
        case .alarmSiren: return "speaker.wave.3.fill"
        case .flashAlert: return "light.beacon.max.fill"
        case .stealthMode: return "eye.slash.fill"
        case .autoLock: return "lock.fill"
        }
    }

    var description: String {
        switch self {
        case .unlimitedHistory: return "Keep captures forever with no 3-day limit"
        case .detectionScheduling: return "Monitor only during configured time windows"
        case .videoRecording: return "Capture 5-second video clips on each detection"
        case .webhookAlerts: return "Send HTTP POST alerts to Slack or custom URLs"
        case .advancedPDFReports: return "Export detailed analytics tables and breakdowns"
        case .statsDashboard: return "View capture trends, heatmaps, and weekly summaries"
        case .alarmSiren: return "Play an audible alarm siren on detection"
        case .flashAlert: return "Flash the screen red/blue on detection"
        case .stealthMode: return "Hide the display while monitoring is active"
        case .autoLock: return "Automatically lock the screen after detection"
        }
    }
}

enum SubscriptionStatus: Equatable {
    case free
    case trial(daysRemaining: Int)
    case subscribed(productID: String, expiresDate: Date)
    case expired

    var displayName: String {
        switch self {
        case .free: return "Free"
        case .trial(let days): return "Trial (\(days) day\(days == 1 ? "" : "s") left)"
        case .subscribed: return "Pro"
        case .expired: return "Expired"
        }
    }

    var isProUser: Bool {
        switch self {
        case .trial, .subscribed: return true
        case .free, .expired: return false
        }
    }
}
