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
    let screenDimManager = ScreenDimManager.shared
    let hotkeyManager = HotkeyManager.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set app icon from bundled .icns
        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: iconURL) {
            NSApplication.shared.applicationIconImage = icon
        }

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
        hotkeyManager.configure(detectionEngine: detectionEngine)

        // Set up notifications (deferred until app has a bundle proxy)
        NotificationManager.shared.setup()

        // Clear attachment copies left behind by a previous session that didn't exit
        // cleanly — a crash or force-quit skips `applicationWillTerminate`.
        NotificationManager.shared.clearTemporaryAttachments()

        // Drop any capture media that has aged out of the free tier's retention window.
        // CaptureStore also re-checks hourly, for sessions that stay open for days.
        captureStore.pruneExpiredCaptures()
    }

    func applicationWillTerminate(_ notification: Notification) {
        detectionEngine.stopMonitoring()
        NotificationManager.shared.clearTemporaryAttachments()
        PowerManager.shared.releaseAll()
        CaptureLocation.releaseAccess()
    }
}
