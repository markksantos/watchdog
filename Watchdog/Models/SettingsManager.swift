import Foundation
import Combine

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
    }

    var historyDayLimit: Int? {
        isPaid ? nil : 3
    }
}
