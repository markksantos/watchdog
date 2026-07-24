import XCTest
import CoreGraphics
@testable import Watchdog

final class MotionSensitivityScaleTests: XCTestCase {
    /// The whole point of the scale is that the displayed number runs the same direction as
    /// the word "sensitive". A higher level must lower the detector's threshold.
    func testHigherLevelMeansLowerThreshold() {
        let low = MotionSensitivityScale.threshold(forLevel: 1)
        let mid = MotionSensitivityScale.threshold(forLevel: 5)
        let high = MotionSensitivityScale.threshold(forLevel: 10)

        XCTAssertGreaterThan(low, mid)
        XCTAssertGreaterThan(mid, high)
    }

    func testLevelRoundTripsThroughThreshold() {
        for level in MotionSensitivityScale.levels {
            let threshold = MotionSensitivityScale.threshold(forLevel: level)
            XCTAssertEqual(MotionSensitivityScale.level(forThreshold: threshold), level)
        }
    }

    func testLevelsClampToRange() {
        XCTAssertEqual(
            MotionSensitivityScale.threshold(forLevel: -5),
            MotionSensitivityScale.threshold(forLevel: 1)
        )
        XCTAssertEqual(
            MotionSensitivityScale.threshold(forLevel: 99),
            MotionSensitivityScale.threshold(forLevel: 10)
        )
    }

    /// Existing installs store a raw threshold; it must map onto a valid level rather than
    /// falling off the end of the scale.
    func testStoredThresholdsMapIntoRange() {
        for threshold in [0.01, 0.05, 0.10, 0.20] {
            let level = MotionSensitivityScale.level(forThreshold: threshold)
            XCTAssertTrue(MotionSensitivityScale.levels.contains(level), "level \(level) out of range for \(threshold)")
        }
    }

    func testThresholdStaysInDetectorRange() {
        for level in MotionSensitivityScale.levels {
            let threshold = MotionSensitivityScale.threshold(forLevel: level)
            XCTAssertGreaterThan(threshold, 0)
            XCTAssertLessThanOrEqual(threshold, 0.20)
        }
    }
}

final class PhotoResolutionTests: XCTestCase {
    func testPresetsCarryPixelSizes() {
        for resolution in PhotoResolution.presets where resolution != .native {
            XCTAssertNotNil(resolution.pixelSize, "\(resolution) should define a pixel size")
        }
    }

    func testNativeAndCustomHaveNoFixedSize() {
        XCTAssertNil(PhotoResolution.native.pixelSize)
        XCTAssertNil(PhotoResolution.custom.pixelSize)
    }

    func testPresetsAscendInArea() {
        let sizes = [PhotoResolution.p480, .p720, .p1080, .p1440, .p2160].compactMap(\.pixelSize)
        let areas = sizes.map { $0.width * $0.height }
        XCTAssertEqual(areas, areas.sorted(), "presets should be listed smallest to largest")
    }
}

final class CaptureScalingTests: XCTestCase {
    private func makeImage(width: Int, height: Int) -> CGImage {
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        )!
        return context.makeImage()!
    }

    func testDownscalesToFitTargetBox() {
        let source = makeImage(width: 1920, height: 1080)
        let scaled = CaptureSettings.scale(source, toFit: CGSize(width: 640, height: 480))

        XCTAssertLessThanOrEqual(scaled.width, 640)
        XCTAssertLessThanOrEqual(scaled.height, 480)
    }

    func testPreservesAspectRatio() {
        let source = makeImage(width: 1920, height: 1080)
        let scaled = CaptureSettings.scale(source, toFit: CGSize(width: 640, height: 480))

        let sourceRatio = 1920.0 / 1080.0
        let scaledRatio = Double(scaled.width) / Double(scaled.height)
        XCTAssertEqual(scaledRatio, sourceRatio, accuracy: 0.01)
    }

    /// Upscaling would invent detail the camera never captured and inflate the file for
    /// nothing, so a target larger than the source must leave the frame untouched.
    func testNeverUpscales() {
        let source = makeImage(width: 640, height: 480)
        let scaled = CaptureSettings.scale(source, toFit: CGSize(width: 3840, height: 2160))

        XCTAssertEqual(scaled.width, 640)
        XCTAssertEqual(scaled.height, 480)
    }

    func testNilTargetReturnsSourceUnchanged() {
        let source = makeImage(width: 1280, height: 720)
        let scaled = CaptureSettings.scale(source, toFit: nil)

        XCTAssertEqual(scaled.width, 1280)
        XCTAssertEqual(scaled.height, 720)
    }

    func testZeroTargetIsIgnored() {
        let source = makeImage(width: 1280, height: 720)
        let scaled = CaptureSettings.scale(source, toFit: CGSize(width: 0, height: 0))

        XCTAssertEqual(scaled.width, 1280)
        XCTAssertEqual(scaled.height, 720)
    }

    func testPortraitSourceFitsInsideLandscapeBox() {
        let source = makeImage(width: 1080, height: 1920)
        let scaled = CaptureSettings.scale(source, toFit: CGSize(width: 1280, height: 720))

        XCTAssertLessThanOrEqual(scaled.width, 1280)
        XCTAssertLessThanOrEqual(scaled.height, 720)
    }
}
