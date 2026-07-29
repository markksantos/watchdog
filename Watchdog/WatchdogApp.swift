import SwiftUI
import Combine

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

    private var cancellables = Set<AnyCancellable>()

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

        // Drop any capture media that has aged out of the free tier's retention window —
        // but only once StoreKit has said who this user actually is.
        //
        // This used to run here, synchronously. At that moment `SubscriptionManager.status`
        // is still its `.free` default (the real value needs an async round trip that cannot
        // have finished), so every trial and paying subscriber had their captures older than
        // three days deleted on each launch, unlinked rather than trashed. Waiting for the
        // answer costs a free user a few seconds of over-retention; not waiting cost
        // subscribers their history.
        //
        // CaptureStore also re-checks hourly, for sessions that stay open for days.
        subscriptionManager.$hasResolvedStatus
            .filter { $0 }
            .first()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.captureStore.pruneExpiredCaptures() }
            .store(in: &cancellables)
    }

    func applicationWillTerminate(_ notification: Notification) {
        detectionEngine.stopMonitoring()
        NotificationManager.shared.clearTemporaryAttachments()
        PowerManager.shared.releaseAll()
        CaptureLocation.releaseAccess()
    }
}
