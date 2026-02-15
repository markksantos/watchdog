import Foundation
import SwiftUI

enum DetectionMode: String, CaseIterable, Codable {
    case faceDetection = "Face Detection"
    case motionDetection = "Motion Detection"
    case alwaysOn = "Always-On"

    var icon: String {
        switch self {
        case .faceDetection: return "face.smiling"
        case .motionDetection: return "figure.walk.motion"
        case .alwaysOn: return "timer"
        }
    }
}

enum CaptureInterval: Int, CaseIterable, Codable {
    case fiveSeconds = 5
    case fifteenSeconds = 15
    case thirtySeconds = 30
    case sixtySeconds = 60

    var label: String {
        switch self {
        case .fiveSeconds: return "5 seconds"
        case .fifteenSeconds: return "15 seconds"
        case .thirtySeconds: return "30 seconds"
        case .sixtySeconds: return "60 seconds"
        }
    }
}

enum PhotoQuality: String, CaseIterable, Codable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"

    var compressionFactor: CGFloat {
        switch self {
        case .low: return 0.3
        case .medium: return 0.6
        case .high: return 0.9
        }
    }
}

struct CaptureRecord: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let detectionType: DetectionMode
    let confidence: Float
    let imagePath: String
    var videoPath: String?

    init(timestamp: Date = Date(), detectionType: DetectionMode, confidence: Float, imagePath: String, videoPath: String? = nil) {
        self.id = UUID()
        self.timestamp = timestamp
        self.detectionType = detectionType
        self.confidence = confidence
        self.imagePath = imagePath
        self.videoPath = videoPath
    }

    var imageURL: URL {
        URL(fileURLWithPath: imagePath)
    }

    var videoURL: URL? {
        guard let videoPath else { return nil }
        return URL(fileURLWithPath: videoPath)
    }

    var hasVideo: Bool {
        videoPath != nil
    }

    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy h:mm:ss a"
        return formatter.string(from: timestamp)
    }

    var shortTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm:ss a"
        return formatter.string(from: timestamp)
    }
}
