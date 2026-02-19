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
    @Published var saveLocation: String {
        didSet { UserDefaults.standard.set(saveLocation, forKey: Keys.saveLocation) }
    }
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
    @Published var webhookURL: String {
        didSet { UserDefaults.standard.set(webhookURL, forKey: Keys.webhookURL) }
    }
    @Published var webhookEnabled: Bool {
        didSet { UserDefaults.standard.set(webhookEnabled, forKey: Keys.webhookEnabled) }
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
    @Published var stealthModeEnabled: Bool {
        didSet { UserDefaults.standard.set(stealthModeEnabled, forKey: Keys.stealthModeEnabled) }
    }
    @Published var autoLockEnabled: Bool {
        didSet { UserDefaults.standard.set(autoLockEnabled, forKey: Keys.autoLockEnabled) }
    }
    @Published var autoLockDelay: Int {
        didSet { UserDefaults.standard.set(autoLockDelay, forKey: Keys.autoLockDelay) }
    }
    @Published var selectedCameraID: String {
        didSet { UserDefaults.standard.set(selectedCameraID, forKey: Keys.selectedCameraID) }
    }

    /// Computed property delegating to SubscriptionManager
    var isPaid: Bool {
        SubscriptionManager.shared.isProUser
    }

    private enum Keys {
        static let detectionMode = "detectionMode"
        static let captureInterval = "captureInterval"
        static let motionSensitivity = "motionSensitivity"
        static let saveLocation = "saveLocation"
        static let notificationsEnabled = "notificationsEnabled"
        static let launchAtLogin = "launchAtLogin"
        static let photoQuality = "photoQuality"
        static let scheduleConfig = "scheduleConfig"
        static let webhookURL = "webhookURL"
        static let webhookEnabled = "webhookEnabled"
        static let videoRecordingEnabled = "videoRecordingEnabled"
        static let preventSleep = "preventSleep"
        static let preventScreenLock = "preventScreenLock"
        static let alarmEnabled = "alarmEnabled"
        static let alarmSound = "alarmSound"
        static let alarmVolume = "alarmVolume"
        static let flashAlertEnabled = "flashAlertEnabled"
        static let stealthModeEnabled = "stealthModeEnabled"
        static let autoLockEnabled = "autoLockEnabled"
        static let autoLockDelay = "autoLockDelay"
        static let selectedCameraID = "selectedCameraID"
    }

    private init() {
        let defaults = UserDefaults.standard
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path

        self.detectionMode = DetectionMode(rawValue: defaults.string(forKey: Keys.detectionMode) ?? "") ?? .faceDetection
        self.captureInterval = CaptureInterval(rawValue: defaults.integer(forKey: Keys.captureInterval)) ?? .fiveSeconds
        self.motionSensitivity = defaults.object(forKey: Keys.motionSensitivity) as? Double ?? 0.05
        self.saveLocation = defaults.string(forKey: Keys.saveLocation) ?? "\(homeDir)/Pictures/Watchdog"
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
        self.webhookURL = defaults.string(forKey: Keys.webhookURL) ?? ""
        self.webhookEnabled = defaults.bool(forKey: Keys.webhookEnabled)
        self.videoRecordingEnabled = defaults.bool(forKey: Keys.videoRecordingEnabled)
        self.preventSleep = defaults.bool(forKey: Keys.preventSleep)
        self.preventScreenLock = defaults.bool(forKey: Keys.preventScreenLock)
        self.alarmEnabled = defaults.bool(forKey: Keys.alarmEnabled)
        self.alarmSound = AlarmSound(rawValue: defaults.string(forKey: Keys.alarmSound) ?? "") ?? .siren
        self.alarmVolume = defaults.object(forKey: Keys.alarmVolume) as? Double ?? 0.8
        self.flashAlertEnabled = defaults.bool(forKey: Keys.flashAlertEnabled)
        self.stealthModeEnabled = defaults.bool(forKey: Keys.stealthModeEnabled)
        self.autoLockEnabled = defaults.bool(forKey: Keys.autoLockEnabled)
        self.autoLockDelay = defaults.object(forKey: Keys.autoLockDelay) as? Int ?? 10
        self.selectedCameraID = defaults.string(forKey: Keys.selectedCameraID) ?? ""
    }

    var historyDayLimit: Int? {
        isPaid ? nil : 3
    }
}
