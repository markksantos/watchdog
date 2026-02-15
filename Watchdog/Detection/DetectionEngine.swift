import AVFoundation
import Combine

class DetectionEngine: NSObject, ObservableObject {
    static let shared = DetectionEngine()

    @Published var isMonitoring: Bool = false

    let cameraManager = CameraManager()
    private let faceDetector = FaceDetector()
    private let motionDetector = MotionDetector()
    private let videoRecorder = VideoRecorder()
    private var currentAnalyzer: FrameAnalyzer?
    private var alwaysOnTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var burstTimer: Timer?

    var onCapture: ((CaptureRecord) -> Void)?

    private override init() {
        super.init()

        faceDetector.onDetection = { [weak self] confidence in
            self?.handleDetection(type: .faceDetection, confidence: confidence)
        }

        motionDetector.onDetection = { [weak self] confidence in
            self?.handleDetection(type: .motionDetection, confidence: confidence)
        }

        SettingsManager.shared.$detectionMode
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, self.isMonitoring else { return }
                self.switchAnalyzer()
            }
            .store(in: &cancellables)
    }

    func startMonitoring() {
        cameraManager.requestPermission { [weak self] granted in
            guard granted, let self else { return }

            self.cameraManager.sampleBufferDelegate = self
            self.cameraManager.startSession()
            self.switchAnalyzer()

            DispatchQueue.main.async {
                self.isMonitoring = true
                SettingsManager.shared.isMonitoring = true
            }
        }
    }

    func stopMonitoring() {
        alwaysOnTimer?.invalidate()
        alwaysOnTimer = nil
        burstTimer?.invalidate()
        burstTimer = nil
        videoRecorder.stopRecording()
        currentAnalyzer = nil
        motionDetector.reset()
        cameraManager.stopSession()

        DispatchQueue.main.async { [weak self] in
            self?.isMonitoring = false
            SettingsManager.shared.isMonitoring = false
        }
    }

    func burstCapture(duration: TimeInterval) {
        burstTimer?.invalidate()
        var elapsed: TimeInterval = 0
        burstTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            elapsed += 1.0
            if elapsed > duration {
                timer.invalidate()
                self?.burstTimer = nil
                return
            }
            self?.captureFrame(type: .alwaysOn, confidence: 1.0)
        }
    }

    private func switchAnalyzer() {
        alwaysOnTimer?.invalidate()
        alwaysOnTimer = nil

        let mode = SettingsManager.shared.detectionMode

        switch mode {
        case .faceDetection:
            currentAnalyzer = faceDetector
        case .motionDetection:
            motionDetector.reset()
            currentAnalyzer = motionDetector
        case .alwaysOn:
            currentAnalyzer = nil
            let interval = TimeInterval(SettingsManager.shared.captureInterval.rawValue)
            alwaysOnTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
                self?.captureFrame(type: .alwaysOn, confidence: 1.0)
            }
        }
    }

    private func handleDetection(type: DetectionMode, confidence: Float) {
        captureFrame(type: type, confidence: confidence)

        // Trigger video recording if pro and enabled
        let videoEnabled = SettingsManager.shared.videoRecordingEnabled
        let isRecording = videoRecorder.isRecording
        guard videoEnabled, !isRecording else { return }

        let dimensions = cameraManager.videoDimensions
        let saveDir = SettingsManager.shared.saveLocation

        DispatchQueue.main.async { [weak self] in
            guard SubscriptionManager.shared.hasAccess(to: .videoRecording) else { return }
            self?.videoRecorder.startRecording(dimensions: dimensions, saveDirectory: saveDir) { [weak self] videoPath in
                if let videoPath {
                    self?.updateLastCaptureWithVideo(videoPath: videoPath)
                }
            }
        }
    }

    private func updateLastCaptureWithVideo(videoPath: String) {
        guard let lastCapture = CaptureStore.shared.captures.first else { return }
        CaptureStore.shared.updateCapture(lastCapture.id, videoPath: videoPath)
    }

    private func captureFrame(type: DetectionMode, confidence: Float) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let record = self?.cameraManager.captureCurrentFrame(
                detectionType: type,
                confidence: confidence
            ) else { return }

            DispatchQueue.main.async {
                self?.onCapture?(record)
            }
        }
    }
}

extension DetectionEngine: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Check schedule — skip processing outside active window
        if SettingsManager.shared.scheduleConfig.isEnabled && !SettingsManager.shared.scheduleConfig.isCurrentlyActive() {
            return
        }

        cameraManager.updateLatestBuffer(sampleBuffer)
        currentAnalyzer?.analyze(sampleBuffer: sampleBuffer)

        // Forward to video recorder if recording
        if videoRecorder.isRecording {
            videoRecorder.appendSampleBuffer(sampleBuffer)
        }
    }
}
