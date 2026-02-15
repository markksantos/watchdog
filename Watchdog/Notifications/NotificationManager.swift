import Foundation
import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()

    private var isSetUp = false

    private init() {}

    func setup() {
        guard !isSetUp else { return }
        guard Bundle.main.bundleIdentifier != nil else {
            print("[Watchdog] No bundle identifier — notifications unavailable")
            return
        }
        isSetUp = true
        requestPermission()
        setupCategories()
    }

    func requestPermission() {
        guard Bundle.main.bundleIdentifier != nil else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("[Watchdog] Notification permission error: \(error)")
            }
            print("[Watchdog] Notifications \(granted ? "granted" : "denied")")
        }
    }

    func sendCaptureNotification(record: CaptureRecord) {
        guard isSetUp,
              SettingsManager.shared.notificationsEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = "Watchdog"
        content.body = "\(record.detectionType.rawValue) at \(record.shortTimestamp)"
        content.categoryIdentifier = "CAPTURE"

        if let attachment = createAttachment(from: record.imageURL) {
            content.attachments = [attachment]
        }

        let request = UNNotificationRequest(
            identifier: record.id.uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[Watchdog] Failed to send notification: \(error)")
            }
        }
    }

    private func setupCategories() {
        let viewAction = UNNotificationAction(
            identifier: "VIEW_ACTION",
            title: "View",
            options: .foreground
        )

        let category = UNNotificationCategory(
            identifier: "CAPTURE",
            actions: [viewAction],
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    private func createAttachment(from imageURL: URL) -> UNNotificationAttachment? {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: imageURL.path) else { return nil }

        let tempDir = fileManager.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent(UUID().uuidString + ".jpg")

        do {
            try fileManager.copyItem(at: imageURL, to: tempFile)
            return try UNNotificationAttachment(
                identifier: UUID().uuidString,
                url: tempFile,
                options: nil
            )
        } catch {
            print("[Watchdog] Failed to create notification attachment: \(error)")
            return nil
        }
    }
}
