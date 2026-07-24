import Foundation
import Combine

enum AlarmSound: String, CaseIterable {
    case siren = "Siren"
    case alert = "Alert"
    case klaxon = "Klaxon"
}

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    @Published var detectionMode: DetectionMode {
        didSet { UserDefaults.standard.set(detectionMode.rawValue, forKey: Keys.detectionMode) }
    }
    @Published var captureInterval: CaptureInterval {
        didSet { UserDefaults.standard.set(captureInterval.rawValue, forKey: Keys.captureInterval) }
    }
    @Published var motionSensitivity: Double {
        didSet { UserDefaults.standard.set(motionSensitivity, forKey: Keys.motionSensitivity) }
    }
    /// Resolved capture directory. Not persisted directly — the source of truth is the
    /// security-scoped bookmark held by `CaptureLocation`, since a bare path grants no
    /// access under the App Sandbox. Set via `setSaveLocation(_:)`.
    @Published private(set) var saveLocation: String
    @Published var notificationsEnabled: Bool {
        didSet { UserDefaults.standard.set(notificationsEnabled, forKey: Keys.notificationsEnabled) }
    }
    @Published var launchAtLogin: Bool {
        didSet { UserDefaults.standard.set(launchAtLogin, forKey: Keys.launchAtLogin) }
    }
    @Published var photoQuality: PhotoQuality {
        didSet { UserDefaults.standard.set(photoQuality.rawValue, forKey: Keys.photoQuality) }
    }
    @Published var isMonitoring: Bool = false

    // Pro settings
    @Published var scheduleConfig: ScheduleConfig {
        didSet {
            if let data = try? JSONEncoder().encode(scheduleConfig) {
                UserDefaults.standard.set(data, forKey: Keys.scheduleConfig)
            }
        }
    }
    @Published var videoRecordingEnabled: Bool {
        didSet { UserDefaults.standard.set(videoRecordingEnabled, forKey: Keys.videoRecordingEnabled) }
    }
    @Published var preventSleep: Bool {
        didSet { UserDefaults.standard.set(preventSleep, forKey: Keys.preventSleep) }
    }
    @Published var preventScreenLock: Bool {
        didSet { UserDefaults.standard.set(preventScreenLock, forKey: Keys.preventScreenLock) }
    }
    @Published var alarmEnabled: Bool {
        didSet { UserDefaults.standard.set(alarmEnabled, forKey: Keys.alarmEnabled) }
    }
    @Published var alarmSound: AlarmSound {
        didSet { UserDefaults.standard.set(alarmSound.rawValue, forKey: Keys.alarmSound) }
    }
    @Published var alarmVolume: Double {
        didSet { UserDefaults.standard.set(alarmVolume, forKey: Keys.alarmVolume) }
    }
    @Published var flashAlertEnabled: Bool {
        didSet { UserDefaults.standard.set(flashAlertEnabled, forKey: Keys.flashAlertEnabled) }
    }
    @Published var screenDimEnabled: Bool {
        didSet { UserDefaults.standard.set(screenDimEnabled, forKey: Keys.screenDimEnabled) }
    }
    @Published var selectedCameraID: String {
        didSet { UserDefaults.standard.set(selectedCameraID, forKey: Keys.selectedCameraID) }
    }

    /// Set once the user has acknowledged the first-run recording notice.
    /// Monitoring cannot start until this is true.
    @Published var hasAcceptedRecordingNotice: Bool {
        didSet { UserDefaults.standard.set(hasAcceptedRecordingNotice, forKey: Keys.hasAcceptedRecordingNotice) }
    }

    /// Computed property delegating to SubscriptionManager
    var isPaid: Bool {
        SubscriptionManager.shared.isProUser
    }

    private enum Keys {
        static let detectionMode = "detectionMode"
        static let captureInterval = "captureInterval"
        static let motionSensitivity = "motionSensitivity"
        static let notificationsEnabled = "notificationsEnabled"
        static let launchAtLogin = "launchAtLogin"
        static let photoQuality = "photoQuality"
        static let scheduleConfig = "scheduleConfig"
        static let videoRecordingEnabled = "videoRecordingEnabled"
        static let preventSleep = "preventSleep"
        static let preventScreenLock = "preventScreenLock"
        static let alarmEnabled = "alarmEnabled"
        static let alarmSound = "alarmSound"
        static let alarmVolume = "alarmVolume"
        static let flashAlertEnabled = "flashAlertEnabled"
        static let screenDimEnabled = "screenDimEnabled"
        static let selectedCameraID = "selectedCameraID"
        static let hasAcceptedRecordingNotice = "hasAcceptedRecordingNotice"
        // The capture folder is persisted as a security-scoped bookmark by CaptureLocation.
    }

    private init() {
        let defaults = UserDefaults.standard

        self.detectionMode = DetectionMode(rawValue: defaults.string(forKey: Keys.detectionMode) ?? "") ?? .faceDetection
        self.captureInterval = CaptureInterval(rawValue: defaults.integer(forKey: Keys.captureInterval)) ?? .fiveSeconds
        self.motionSensitivity = defaults.object(forKey: Keys.motionSensitivity) as? Double ?? 0.05
        self.saveLocation = CaptureLocation.resolveAtLaunch().path
        self.notificationsEnabled = defaults.object(forKey: Keys.notificationsEnabled) as? Bool ?? true
        self.launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
        self.photoQuality = PhotoQuality(rawValue: defaults.string(forKey: Keys.photoQuality) ?? "") ?? .high

        // Pro settings
        if let data = defaults.data(forKey: Keys.scheduleConfig),
           let config = try? JSONDecoder().decode(ScheduleConfig.self, from: data) {
            self.scheduleConfig = config
        } else {
            self.scheduleConfig = ScheduleConfig()
        }
        self.videoRecordingEnabled = defaults.bool(forKey: Keys.videoRecordingEnabled)
        self.preventSleep = defaults.bool(forKey: Keys.preventSleep)
        self.preventScreenLock = defaults.bool(forKey: Keys.preventScreenLock)
        self.alarmEnabled = defaults.bool(forKey: Keys.alarmEnabled)
        self.alarmSound = AlarmSound(rawValue: defaults.string(forKey: Keys.alarmSound) ?? "") ?? .siren
        self.alarmVolume = defaults.object(forKey: Keys.alarmVolume) as? Double ?? 0.8
        self.flashAlertEnabled = defaults.bool(forKey: Keys.flashAlertEnabled)
        self.screenDimEnabled = defaults.bool(forKey: Keys.screenDimEnabled)
        self.selectedCameraID = defaults.string(forKey: Keys.selectedCameraID) ?? ""
        self.hasAcceptedRecordingNotice = defaults.bool(forKey: Keys.hasAcceptedRecordingNotice)
    }

    /// Adopts a folder the user chose in Preferences, persisting sandbox access to it.
    func setSaveLocation(_ url: URL) {
        saveLocation = CaptureLocation.setCustomDirectory(url).path
    }

    /// Reverts the capture folder to `~/Pictures/Watchdog`.
    func resetSaveLocationToDefault() {
        CaptureLocation.resetToDefault()
        saveLocation = CaptureLocation.defaultDirectory.path
    }

    var historyDayLimit: Int? {
        isPaid ? nil : 3
    }
}
