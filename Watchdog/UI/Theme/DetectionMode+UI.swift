import Foundation

extension DetectionMode {
    /// Compact name for narrow controls such as the menu bar popover's mode switch, where the
    /// full "Motion Detection" / "Face Detection" strings do not fit side by side.
    var shortName: String {
        switch self {
        case .faceDetection: return "Face"
        case .motionDetection: return "Motion"
        case .alwaysOn: return "Always-On"
        }
    }

    /// One-line explanation of what this mode does, shown under the mode picker.
    var explanation: String {
        switch self {
        case .faceDetection:
            return "Captures when a face appears in front of the camera. Best for a desk you want to know about people approaching."
        case .motionDetection:
            return "Captures when enough of the frame changes. Best for doorways and rooms, and adjustable below."
        case .alwaysOn:
            return "Captures on a fixed timer regardless of what the camera sees. Best for time-lapse style records."
        }
    }
}

// MARK: - Motion sensitivity

/// Translates between the stored motion threshold and the 1–10 scale shown in Preferences.
///
/// `MotionDetector` fires when the fraction of changed pixels exceeds
/// `SettingsManager.motionSensitivity`, so a *larger* stored value means a *less* sensitive
/// detector. Exposing that number directly meant the slider ran backwards from the label —
/// dragging right made it harder to trigger. This maps it to a level where higher always
/// means more sensitive, which is the direction users expect and the direction the turtle and
/// rabbit markers imply.
enum MotionSensitivityScale {
    static let levels = 1...10

    /// Stored threshold for a 1–10 level. Level 1 ≈ 0.19 (large movements only),
    /// level 10 ≈ 0.01 (very small movements).
    static func threshold(forLevel level: Int) -> Double {
        let clamped = min(max(level, levels.lowerBound), levels.upperBound)
        return 0.21 - Double(clamped) * 0.02
    }

    /// Level matching a stored threshold, for reading existing settings back.
    static func level(forThreshold threshold: Double) -> Int {
        let raw = ((0.21 - threshold) / 0.02).rounded()
        return min(max(Int(raw), levels.lowerBound), levels.upperBound)
    }

    /// What this level will realistically pick up, shown as a hint under the slider.
    static func example(forLevel level: Int) -> String {
        switch level {
        case ...3:
            return "Example: Large movements — someone walking into frame"
        case 4...7:
            return "Example: Normal movement — a person sitting down or reaching across the desk"
        default:
            return "Example: Small movements — a hand gesture, or a shift in lighting"
        }
    }
}
