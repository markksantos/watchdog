import XCTest
@testable import Watchdog

final class CaptureRecordTests: XCTestCase {

    func testCodableRoundTrip() throws {
        let record = CaptureRecord(
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            detectionType: .faceDetection,
            confidence: 0.87,
            imagePath: "/tmp/watchdog/a.jpg",
            videoPath: "/tmp/watchdog/a.mov"
        )

        let data = try JSONEncoder().encode(record)
        let decoded = try JSONDecoder().decode(CaptureRecord.self, from: data)

        XCTAssertEqual(decoded.id, record.id)
        XCTAssertEqual(decoded.timestamp.timeIntervalSince1970, record.timestamp.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(decoded.detectionType, .faceDetection)
        XCTAssertEqual(decoded.confidence, 0.87, accuracy: 0.0001)
        XCTAssertEqual(decoded.imagePath, "/tmp/watchdog/a.jpg")
        XCTAssertEqual(decoded.videoPath, "/tmp/watchdog/a.mov")
    }

    func testHasVideoReflectsVideoPath() {
        let withVideo = CaptureRecord(detectionType: .motionDetection, confidence: 1, imagePath: "/a.jpg", videoPath: "/a.mov")
        let withoutVideo = CaptureRecord(detectionType: .motionDetection, confidence: 1, imagePath: "/a.jpg")
        XCTAssertTrue(withVideo.hasVideo)
        XCTAssertFalse(withoutVideo.hasVideo)
        XCTAssertNil(withoutVideo.videoURL)
        XCTAssertNotNil(withVideo.videoURL)
    }

    func testImageURLDerivedFromPath() {
        let record = CaptureRecord(detectionType: .alwaysOn, confidence: 1, imagePath: "/tmp/x.jpg")
        XCTAssertEqual(record.imageURL.path, "/tmp/x.jpg")
    }

    func testEachRecordGetsUniqueID() {
        let a = CaptureRecord(detectionType: .alwaysOn, confidence: 1, imagePath: "/x.jpg")
        let b = CaptureRecord(detectionType: .alwaysOn, confidence: 1, imagePath: "/x.jpg")
        XCTAssertNotEqual(a.id, b.id)
    }

    func testCaptureIntervalRawValuesAreSeconds() {
        XCTAssertEqual(CaptureInterval.fiveSeconds.rawValue, 5)
        XCTAssertEqual(CaptureInterval.sixtySeconds.rawValue, 60)
        XCTAssertEqual(CaptureInterval(rawValue: 30), .thirtySeconds)
    }

    func testPhotoQualityCompressionOrdering() {
        XCTAssertLessThan(PhotoQuality.low.compressionFactor, PhotoQuality.medium.compressionFactor)
        XCTAssertLessThan(PhotoQuality.medium.compressionFactor, PhotoQuality.high.compressionFactor)
    }
}
