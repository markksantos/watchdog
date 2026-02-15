import Foundation
import SwiftUI
import Combine

class CaptureStore: ObservableObject {
    static let shared = CaptureStore()

    @Published var captures: [CaptureRecord] = []
    @Published var lastCapture: CaptureRecord?

    private var metadataURL: URL {
        URL(fileURLWithPath: SettingsManager.shared.saveLocation)
            .appendingPathComponent("captures.json")
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
        WebhookManager.sendWebhook(for: record)
    }

    func updateCapture(_ id: UUID, videoPath: String) {
        if let index = captures.firstIndex(where: { $0.id == id }) {
            captures[index].videoPath = videoPath
            saveCaptureMetadata()
        }
    }

    func deleteCapture(_ record: CaptureRecord) {
        captures.removeAll { $0.id == record.id }
        if let videoPath = record.videoPath {
            try? FileManager.default.removeItem(atPath: videoPath)
        }
        try? FileManager.default.removeItem(atPath: record.imagePath)
        saveCaptureMetadata()
    }

    func deleteAllCaptures() {
        for capture in captures {
            if let videoPath = capture.videoPath {
                try? FileManager.default.removeItem(atPath: videoPath)
            }
            try? FileManager.default.removeItem(atPath: capture.imagePath)
        }
        captures.removeAll()
        lastCapture = nil
        saveCaptureMetadata()
    }

    func loadCaptures() {
        guard FileManager.default.fileExists(atPath: metadataURL.path) else { return }

        do {
            let data = try Data(contentsOf: metadataURL)
            var decoded = try JSONDecoder().decode([CaptureRecord].self, from: data)

            // Enforce free tier 3-day limit
            if !SettingsManager.shared.isPaid {
                let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date()
                decoded = decoded.filter { $0.timestamp > threeDaysAgo }
            }

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
            print("[Watchdog] Failed to load captures: \(error)")
        }
    }

    func saveCaptureMetadata() {
        do {
            let directory = metadataURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(captures)
            try data.write(to: metadataURL, options: .atomic)
        } catch {
            print("[Watchdog] Failed to save capture metadata: \(error)")
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
