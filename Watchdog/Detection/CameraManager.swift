import AVFoundation
#if canImport(AppKit)
import AppKit
#endif

class CameraManager: NSObject {
    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureVideoDataOutput?
    private let processingQueue = DispatchQueue(label: "com.watchdog.camera")
    private var latestSampleBuffer: CMSampleBuffer?
    private let bufferLock = NSLock()

    var videoDimensions: CMVideoDimensions {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            return CMVideoDimensions(width: 640, height: 480)
        }
        return CMVideoFormatDescriptionGetDimensions(device.activeFormat.formatDescription)
    }

    var sampleBufferDelegate: AVCaptureVideoDataOutputSampleBufferDelegate? {
        didSet {
            videoOutput?.setSampleBufferDelegate(sampleBufferDelegate, queue: processingQueue)
        }
    }

    func requestPermission(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async { completion(granted) }
            }
        default:
            completion(false)
        }
    }

    func startSession() {
        guard captureSession == nil else { return }

        let session = AVCaptureSession()
        session.sessionPreset = .medium

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: camera),
              session.canAddInput(input) else {
            return
        }
        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)

        self.videoOutput = output
        self.captureSession = session

        if let delegate = sampleBufferDelegate {
            output.setSampleBufferDelegate(delegate, queue: processingQueue)
        }

        processingQueue.async {
            session.startRunning()
        }
    }

    func stopSession() {
        processingQueue.async { [weak self] in
            self?.captureSession?.stopRunning()
            DispatchQueue.main.async {
                self?.captureSession = nil
                self?.videoOutput = nil
                self?.bufferLock.lock()
                self?.latestSampleBuffer = nil
                self?.bufferLock.unlock()
            }
        }
    }

    func updateLatestBuffer(_ sampleBuffer: CMSampleBuffer) {
        bufferLock.lock()
        latestSampleBuffer = sampleBuffer
        bufferLock.unlock()
    }

    func captureCurrentFrame(detectionType: DetectionMode, confidence: Float) -> CaptureRecord? {
        bufferLock.lock()
        guard let sampleBuffer = latestSampleBuffer else {
            bufferLock.unlock()
            return nil
        }
        bufferLock.unlock()

        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }

        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }

        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        guard let tiffData = nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmap.representation(
                  using: .jpeg,
                  properties: [.compressionFactor: SettingsManager.shared.photoQuality.compressionFactor]
              ) else {
            return nil
        }

        let saveDir = SettingsManager.shared.saveLocation
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: saveDir) {
            try? fileManager.createDirectory(atPath: saveDir, withIntermediateDirectories: true)
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let filename = "\(formatter.string(from: Date())).jpg"
        let filePath = (saveDir as NSString).appendingPathComponent(filename)

        do {
            try jpegData.write(to: URL(fileURLWithPath: filePath))
        } catch {
            return nil
        }

        return CaptureRecord(
            detectionType: detectionType,
            confidence: confidence,
            imagePath: filePath
        )
    }
}
