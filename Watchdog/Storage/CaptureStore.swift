import Foundation
import SwiftUI
import Combine
import os

class CaptureStore: ObservableObject {
    static let shared = CaptureStore()

    @Published var captures: [CaptureRecord] = []
    @Published var lastCapture: CaptureRecord?

    private let log = Logger(subsystem: "com.markstudios.watchdog", category: "storage")

    private var metadataURL: URL {
        CaptureLocation.currentDirectory.appendingPathComponent("captures.json")
    }

    private init() {
        loadCaptures()
    }

    // MARK: - Public Methods

    func addCapture(_ record: CaptureRecord) {
        captures.insert(record, at: 0)
        lastCapture = record
        saveCaptureMetadata()
        NotificationManager.shared.sendCaptureNotification(record: record)
    }

    func updateCapture(_ id: UUID, videoPath: String) {
        if let index = captures.firstIndex(where: { $0.id == id }) {
            captures[index].videoPath = videoPath
            saveCaptureMetadata()
        }
    }

    func deleteCapture(_ record: CaptureRecord) {
        captures.removeAll { $0.id == record.id }
        removeMedia(for: record)
        if lastCapture?.id == record.id {
            lastCapture = captures.first
        }
        saveCaptureMetadata()
    }

    func deleteAllCaptures() {
        for capture in captures {
            removeMedia(for: capture)
        }
        captures.removeAll()
        lastCapture = nil
        saveCaptureMetadata()
    }

    /// Enforces the retention window by **deleting the media**, not merely hiding it.
    ///
    /// The previous implementation filtered aged-out records out of the in-memory list and
    /// then persisted the shortened list, which orphaned the underlying `.jpg`/`.mov` files:
    /// photographs of people accumulated on disk forever with no way for the user to find or
    /// remove them. Retention has to actually delete, both to keep the promise the UI makes
    /// and to avoid hoarding images of third parties indefinitely.
    func pruneExpiredCaptures() {
        guard let dayLimit = SettingsManager.shared.historyDayLimit,
              let cutoff = Calendar.current.date(byAdding: .day, value: -dayLimit, to: Date())
        else { return }

        let expired = captures.filter { $0.timestamp <= cutoff }
        guard !expired.isEmpty else { return }

        for record in expired {
            removeMedia(for: record)
        }
        captures.removeAll { $0.timestamp <= cutoff }
        lastCapture = captures.first
        saveCaptureMetadata()

        log.info("Pruned \(expired.count, privacy: .public) capture(s) past the \(dayLimit, privacy: .public)-day retention window")
    }

    private func removeMedia(for record: CaptureRecord) {
        if let videoPath = record.videoPath {
            try? FileManager.default.removeItem(atPath: videoPath)
        }
        try? FileManager.default.removeItem(atPath: record.imagePath)
    }

    func loadCaptures() {
        guard FileManager.default.fileExists(atPath: metadataURL.path) else { return }

        do {
            let data = try Data(contentsOf: metadataURL)
            var decoded = try JSONDecoder().decode([CaptureRecord].self, from: data)

            // Remove records whose image files no longer exist
            decoded = decoded.filter { FileManager.default.fileExists(atPath: $0.imagePath) }

            // Clear stale video path references
            for i in decoded.indices {
                if let videoPath = decoded[i].videoPath,
                   !FileManager.default.fileExists(atPath: videoPath) {
                    decoded[i].videoPath = nil
                }
            }

            // Sort newest first
            decoded.sort { $0.timestamp > $1.timestamp }

            captures = decoded
            lastCapture = decoded.first
        } catch {
            log.error("Failed to load captures: \(error.localizedDescription, privacy: .public)")
        }
    }

    func saveCaptureMetadata() {
        do {
            let directory = metadataURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(captures)
            try data.write(to: metadataURL, options: .atomic)
        } catch {
            log.error("Failed to save capture metadata: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Computed Properties

    var todayCount: Int {
        let calendar = Calendar.current
        return captures.filter { calendar.isDateInToday($0.timestamp) }.count
    }

    var capturesGroupedByDay: [(String, [CaptureRecord])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: captures) { record -> String in
            if calendar.isDateInToday(record.timestamp) {
                return "Today"
            } else if calendar.isDateInYesterday(record.timestamp) {
                return "Yesterday"
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM d, yyyy"
                return formatter.string(from: record.timestamp)
            }
        }

        return grouped.sorted { lhs, rhs in
            guard let lhsDate = lhs.value.first?.timestamp,
                  let rhsDate = rhs.value.first?.timestamp else { return false }
            return lhsDate > rhsDate
        }
    }
}
