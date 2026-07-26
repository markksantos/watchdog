import Foundation
import UserNotifications
import os

class NotificationManager {
    static let shared = NotificationManager()

    private let log = Logger(subsystem: "com.markstudios.watchdog", category: "notifications")
    private var isSetUp = false

    /// Notification attachments have to live in a file the system can read, so each capture
    /// is copied into a temp directory. Track them so they can be removed — otherwise every
    /// detection leaves a photograph of a person in `/tmp` indefinitely.
    private let attachmentDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("CaptureAttachments", isDirectory: true)

    private init() {}

    func setup() {
        guard !isSetUp else { return }
        guard Bundle.main.bundleIdentifier != nil else {
            log.error("No bundle identifier — notifications unavailable")
            return
        }
        isSetUp = true
        requestPermission()
        setupCategories()
    }

    func requestPermission() {
        guard Bundle.main.bundleIdentifier != nil else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, error in
            if let error {
                self?.log.error("Notification permission error: \(error.localizedDescription, privacy: .public)")
            }
            self?.log.info("Notification permission \(granted ? "granted" : "denied", privacy: .public)")
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

        UNUserNotificationCenter.current().add(request) { [weak self] error in
            if let error {
                self?.log.error("Failed to send notification: \(error.localizedDescription, privacy: .public)")
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

        do {
            try fileManager.createDirectory(at: attachmentDirectory, withIntermediateDirectories: true)
            let tempFile = attachmentDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
            try fileManager.copyItem(at: imageURL, to: tempFile)
            return try UNNotificationAttachment(
                identifier: UUID().uuidString,
                url: tempFile,
                options: nil
            )
        } catch {
            log.error("Failed to create notification attachment: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// Deletes the copies of captures made for notification attachments.
    ///
    /// Called both on graceful termination *and* at launch. Termination alone isn't enough:
    /// a force-quit, crash, or logout skips `applicationWillTerminate` entirely, and every
    /// one of these files is a photograph of a person. Clearing at startup guarantees they
    /// survive at most one session however the previous one ended.
    func clearTemporaryAttachments() {
        try? FileManager.default.removeItem(at: attachmentDirectory)
    }
}
