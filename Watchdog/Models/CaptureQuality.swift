import Foundation
import CoreGraphics
import Combine

// MARK: - Resolution

/// The pixel size captures are saved at.
///
/// Replaces the old three-step Low/Medium/High enum, which only ever changed JPEG compression
/// and left resolution untouched — so "Low" still wrote a full-size frame and saved far less
/// space than users expected. Resolution and compression are now independent, because they
/// trade off differently: resolution decides how much detail exists, compression decides how
/// cleanly that detail is stored.
enum PhotoResolution: String, CaseIterable, Codable, Identifiable {
    case p480, p720, p1080, p1440, p2160, native, custom

    var id: String { rawValue }

    /// Presets shown as pills. `custom` is offered separately so it can reveal its fields.
    static var presets: [PhotoResolution] { [.p480, .p720, .p1080, .p1440, .p2160, .native] }

    /// Target box in pixels, or `nil` for "whatever the camera produced".
    var pixelSize: CGSize? {
        switch self {
        case .p480: return CGSize(width: 640, height: 480)
        case .p720: return CGSize(width: 1280, height: 720)
        case .p1080: return CGSize(width: 1920, height: 1080)
        case .p1440: return CGSize(width: 2560, height: 1440)
        case .p2160: return CGSize(width: 3840, height: 2160)
        case .native, .custom: return nil
        }
    }

    var label: String {
        switch self {
        case .p480: return "640×480"
        case .p720: return "1280×720"
        case .p1080: return "1920×1080"
        case .p1440: return "2560×1440"
        case .p2160: return "3840×2160"
        case .native: return "Native"
        case .custom: return "Custom"
        }
    }

    /// Short name used where space is tight.
    var shortLabel: String {
        switch self {
        case .p480: return "480p"
        case .p720: return "720p"
        case .p1080: return "1080p"
        case .p1440: return "1440p"
        case .p2160: return "4K"
        case .native: return "Native"
        case .custom: return "Custom"
        }
    }
}

// MARK: - Interval presets

/// Preset gaps between shots in Always-On mode. The stored value is a plain second count, so
/// any value in `CaptureSettings.intervalRange` is reachable via Custom.
enum IntervalPreset: Int, CaseIterable, Identifiable {
    case fiveSeconds = 5
    case tenSeconds = 10
    case fifteenSeconds = 15
    case thirtySeconds = 30
    case oneMinute = 60
    case fiveMinutes = 300

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .fiveSeconds: return "5s"
        case .tenSeconds: return "10s"
        case .fifteenSeconds: return "15s"
        case .thirtySeconds: return "30s"
        case .oneMinute: return "1 min"
        case .fiveMinutes: return "5 min"
        }
    }
}

// MARK: - Settings store

/// Capture quality and cadence.
///
/// Kept out of `SettingsManager` so the capture-behaviour and image-quality concerns stay
/// separable. Values are read by `CameraManager` when encoding a frame and by
/// `DetectionEngine` when scheduling Always-On shots.
final class CaptureSettings: ObservableObject {
    static let shared = CaptureSettings()

    /// Allowed custom pixel dimensions. The ceiling is well past any current webcam; the floor
    /// is small enough to be useful for long unattended runs but still recognisable.
    static let dimensionRange = 160...7680
    /// Allowed Always-On gap, from one second to one hour.
    static let intervalRange = 1...3600

    @Published var resolution: PhotoResolution {
        didSet { UserDefaults.standard.set(resolution.rawValue, forKey: Keys.resolution) }
    }

    @Published var customWidth: Int {
        didSet {
            customWidth = customWidth.clamped(to: Self.dimensionRange)
            UserDefaults.standard.set(customWidth, forKey: Keys.customWidth)
        }
    }

    @Published var customHeight: Int {
        didSet {
            customHeight = customHeight.clamped(to: Self.dimensionRange)
            UserDefaults.standard.set(customHeight, forKey: Keys.customHeight)
        }
    }

    /// JPEG quality, 0.1–1.0.
    @Published var compression: Double {
        didSet {
            compression = min(max(compression, 0.1), 1.0)
            UserDefaults.standard.set(compression, forKey: Keys.compression)
        }
    }

    /// Seconds between Always-On captures.
    @Published var intervalSeconds: Int {
        didSet {
            intervalSeconds = intervalSeconds.clamped(to: Self.intervalRange)
            UserDefaults.standard.set(intervalSeconds, forKey: Keys.intervalSeconds)
        }
    }

    private enum Keys {
        static let resolution = "capture.resolution"
        static let customWidth = "capture.customWidth"
        static let customHeight = "capture.customHeight"
        static let compression = "capture.compression"
        static let intervalSeconds = "capture.intervalSeconds"
        static let didMigrate = "capture.didMigrateFromPhotoQuality"
    }

    private init() {
        let defaults = UserDefaults.standard

        self.resolution = PhotoResolution(rawValue: defaults.string(forKey: Keys.resolution) ?? "") ?? .native
        self.customWidth = (defaults.object(forKey: Keys.customWidth) as? Int ?? 1600)
            .clamped(to: Self.dimensionRange)
        self.customHeight = (defaults.object(forKey: Keys.customHeight) as? Int ?? 900)
            .clamped(to: Self.dimensionRange)
        self.compression = min(max(defaults.object(forKey: Keys.compression) as? Double ?? 0.9, 0.1), 1.0)
        self.intervalSeconds = (defaults.object(forKey: Keys.intervalSeconds) as? Int ?? 5)
            .clamped(to: Self.intervalRange)

        migrateLegacyValuesIfNeeded()
    }

    /// Carries existing installs across from the old Low/Medium/High + fixed-interval settings,
    /// so upgrading doesn't silently reset someone's configuration.
    private func migrateLegacyValuesIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: Keys.didMigrate) else { return }

        if let legacyQuality = defaults.string(forKey: "photoQuality"),
           let quality = PhotoQuality(rawValue: legacyQuality) {
            compression = Double(quality.compressionFactor)
        }

        let legacyInterval = defaults.integer(forKey: "captureInterval")
        if Self.intervalRange.contains(legacyInterval) {
            intervalSeconds = legacyInterval
        }

        defaults.set(true, forKey: Keys.didMigrate)
    }

    // MARK: - Derived

    /// The target box a captured frame is scaled into, or `nil` to keep the camera's own size.
    var targetPixelSize: CGSize? {
        switch resolution {
        case .custom: return CGSize(width: customWidth, height: customHeight)
        default: return resolution.pixelSize
        }
    }

    /// Human-readable summary for the Preferences header, e.g. `1920×1080 · 90%`.
    var summary: String {
        let size: String
        switch resolution {
        case .native: size = "Native"
        case .custom: size = "\(customWidth)×\(customHeight)"
        default: size = resolution.label
        }
        return "\(size) · \(Int(compression * 100))%"
    }

    /// Formatted gap between Always-On shots, e.g. `90s` or `5 min`.
    var intervalLabel: String {
        if intervalSeconds < 60 { return "\(intervalSeconds)s" }
        let minutes = Double(intervalSeconds) / 60
        return minutes == minutes.rounded()
            ? "\(Int(minutes)) min"
            : String(format: "%.1f min", minutes)
    }

    func resetToDefaults() {
        resolution = .native
        customWidth = 1600
        customHeight = 900
        compression = 0.9
        intervalSeconds = 5
    }
}

// MARK: - Scaling

extension CaptureSettings {
    /// Scales `image` to fit inside `target`, preserving aspect ratio.
    ///
    /// Only ever downscales — asking for 4K from a 720p webcam would just interpolate detail
    /// that was never captured and inflate the file for nothing, so the frame is left alone.
    /// Returns the original image when no resizing is needed or the redraw fails.
    static func scale(_ image: CGImage, toFit target: CGSize?) -> CGImage {
        guard let target, target.width > 0, target.height > 0 else { return image }

        let sourceWidth = CGFloat(image.width)
        let sourceHeight = CGFloat(image.height)
        guard sourceWidth > 0, sourceHeight > 0 else { return image }

        let ratio = min(target.width / sourceWidth, target.height / sourceHeight)
        guard ratio < 1 else { return image }

        let width = Int((sourceWidth * ratio).rounded())
        let height = Int((sourceHeight * ratio).rounded())
        guard width > 0, height > 0 else { return image }

        guard let colorSpace = image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil,
                  width: width,
                  height: height,
                  bitsPerComponent: 8,
                  bytesPerRow: 0,
                  space: colorSpace,
                  bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
              )
        else { return image }

        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage() ?? image
    }
}

// MARK: - Helpers

private extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
