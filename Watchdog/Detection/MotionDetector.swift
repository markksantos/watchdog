import CoreMedia
import CoreVideo
import Accelerate

class MotionDetector: FrameAnalyzer {
    var onDetection: ((Float) -> Void)?

    private var previousGrayscale: [Float]?
    private var previousWidth: Int = 0
    private var previousHeight: Int = 0
    private var lastDetectionTime: Date = .distantPast
    private let debounceInterval: TimeInterval = 3.0
    private var isProcessing = false

    func analyze(sampleBuffer: CMSampleBuffer) {
        guard !isProcessing else { return }
        guard Date().timeIntervalSince(lastDetectionTime) >= debounceInterval else { return }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        isProcessing = true
        defer { isProcessing = false }

        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let pixelCount = width * height

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return }

        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let currentGrayscale = convertToGrayscale(
            baseAddress: baseAddress,
            width: width,
            height: height,
            bytesPerRow: bytesPerRow
        )

        guard let previous = previousGrayscale,
              previousWidth == width,
              previousHeight == height else {
            previousGrayscale = currentGrayscale
            previousWidth = width
            previousHeight = height
            return
        }

        previousGrayscale = currentGrayscale
        previousWidth = width
        previousHeight = height

        var diff = [Float](repeating: 0, count: pixelCount)
        vDSP_vsub(previous, 1, currentGrayscale, 1, &diff, 1, vDSP_Length(pixelCount))
        vDSP_vabs(diff, 1, &diff, 1, vDSP_Length(pixelCount))

        let threshold: Float = 0.1
        var changedCount: Float = 0
        for i in 0..<pixelCount {
            if diff[i] > threshold {
                changedCount += 1
            }
        }

        let changePercentage = changedCount / Float(pixelCount)
        let sensitivity = Float(SettingsManager.shared.motionSensitivity)

        if changePercentage > sensitivity {
            lastDetectionTime = Date()
            onDetection?(changePercentage)
        }
    }

    private func convertToGrayscale(baseAddress: UnsafeMutableRawPointer, width: Int, height: Int, bytesPerRow: Int) -> [Float] {
        let pixelCount = width * height
        var grayscale = [Float](repeating: 0, count: pixelCount)
        let ptr = baseAddress.assumingMemoryBound(to: UInt8.self)

        for y in 0..<height {
            let rowOffset = y * bytesPerRow
            for x in 0..<width {
                let pixelOffset = rowOffset + x * 4
                let b = Float(ptr[pixelOffset]) / 255.0
                let g = Float(ptr[pixelOffset + 1]) / 255.0
                let r = Float(ptr[pixelOffset + 2]) / 255.0
                grayscale[y * width + x] = 0.299 * r + 0.587 * g + 0.114 * b
            }
        }
        return grayscale
    }

    func reset() {
        previousGrayscale = nil
    }
}
