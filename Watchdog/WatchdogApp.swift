import SwiftUI

@main
struct WatchdogApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            PreferencesView()
                .environmentObject(appDelegate.settingsManager)
                .environmentObject(appDelegate.captureStore)
                .environmentObject(SubscriptionManager.shared)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarController: StatusBarController?
    let settingsManager = SettingsManager.shared
    let captureStore = CaptureStore.shared
    let detectionEngine = DetectionEngine.shared
    let wakeDetector = WakeDetector.shared
    let powerManager = PowerManager.shared
    let subscriptionManager = SubscriptionManager.shared
    let alarmManager = AlarmManager.shared
    let flashAlertController = FlashAlertController.shared
    let stealthModeManager = StealthModeManager.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Wire detection captures into the store
        detectionEngine.onCapture = { [weak self] record in
            self?.captureStore.addCapture(record)
        }

        statusBarController = StatusBarController(
            settingsManager: settingsManager,
            captureStore: captureStore,
            detectionEngine: detectionEngine,
            subscriptionManager: subscriptionManager
        )
        wakeDetector.configure(detectionEngine: detectionEngine)

        // Set up notifications (deferred until app has a bundle proxy)
        NotificationManager.shared.setup()
    }
}
