import Vision
import CoreMedia

protocol FrameAnalyzer: AnyObject {
    func analyze(sampleBuffer: CMSampleBuffer)
    var onDetection: ((Float) -> Void)? { get set }
}

class FaceDetector: FrameAnalyzer {
    var onDetection: ((Float) -> Void)?

    private var lastDetectionTime: Date = .distantPast
    private let debounceInterval: TimeInterval = 3.0
    private var isProcessing = false

    func analyze(sampleBuffer: CMSampleBuffer) {
        guard !isProcessing else { return }

        guard Date().timeIntervalSince(lastDetectionTime) >= debounceInterval else { return }

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        isProcessing = true

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        let request = VNDetectFaceRectanglesRequest { [weak self] request, error in
            defer { self?.isProcessing = false }

            guard error == nil,
                  let results = request.results as? [VNFaceObservation],
                  let face = results.first,
                  face.confidence > 0.5 else {
                return
            }

            self?.lastDetectionTime = Date()
            self?.onDetection?(face.confidence)
        }

        do {
            try handler.perform([request])
        } catch {
            isProcessing = false
        }
    }
}
