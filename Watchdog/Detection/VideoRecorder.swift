import AVFoundation

class VideoRecorder {
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var adaptor: AVAssetWriterInputPixelBufferAdaptor?
    private let recordingQueue = DispatchQueue(label: "com.watchdog.videoRecorder")
    private var stopTimer: Timer?
    private var isSessionStarted = false
    private var _isRecording = false
    private let recordingLock = NSLock()

    var isRecording: Bool {
        recordingLock.lock()
        defer { recordingLock.unlock() }
        return _isRecording
    }
    private var completion: ((String?) -> Void)?
    private var outputPath: String?

    func startRecording(dimensions: CMVideoDimensions, saveDirectory: String, completion: @escaping (String?) -> Void) {
        recordingQueue.async { [weak self] in
            guard let self, !self._isRecording else {
                completion(nil)
                return
            }

            self.completion = completion

            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
            let filename = "\(formatter.string(from: Date())).mov"
            let filePath = (saveDirectory as NSString).appendingPathComponent(filename)
            self.outputPath = filePath

            let url = URL(fileURLWithPath: filePath)

            // Create directory if needed
            try? FileManager.default.createDirectory(atPath: saveDirectory, withIntermediateDirectories: true)

            // Remove existing file
            try? FileManager.default.removeItem(at: url)

            guard let writer = try? AVAssetWriter(url: url, fileType: .mov) else {
                completion(nil)
                return
            }

            let settings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: Int(dimensions.width),
                AVVideoHeightKey: Int(dimensions.height)
            ]

            let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
            input.expectsMediaDataInRealTime = true

            let adaptor = AVAssetWriterInputPixelBufferAdaptor(
                assetWriterInput: input,
                sourcePixelBufferAttributes: nil
            )

            writer.add(input)

            self.assetWriter = writer
            self.videoInput = input
            self.adaptor = adaptor
            self.isSessionStarted = false
            self._isRecording = true

            writer.startWriting()

            // Auto-stop after 5 seconds
            DispatchQueue.main.async {
                self.stopTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
                    self?.stopRecording()
                }
            }
        }
    }

    func appendSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        recordingQueue.async { [weak self] in
            guard let self,
                  self._isRecording,
                  let writer = self.assetWriter,
                  writer.status == .writing,
                  let input = self.videoInput,
                  input.isReadyForMoreMediaData else { return }

            if !self.isSessionStarted {
                let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                writer.startSession(atSourceTime: timestamp)
                self.isSessionStarted = true
            }

            input.append(sampleBuffer)
        }
    }

    func stopRecording() {
        recordingQueue.async { [weak self] in
            guard let self, self._isRecording else { return }
            self._isRecording = false

            DispatchQueue.main.async {
                self.stopTimer?.invalidate()
                self.stopTimer = nil
            }

            guard let writer = self.assetWriter, writer.status == .writing else {
                let cb = self.completion
                self.completion = nil
                cb?(nil)
                self.cleanup()
                return
            }

            self.videoInput?.markAsFinished()
            writer.finishWriting { [weak self] in
                guard let self else { return }
                let path = writer.status == .completed ? self.outputPath : nil
                let cb = self.completion
                self.completion = nil
                DispatchQueue.main.async {
                    cb?(path)
                }
                self.cleanup()
            }
        }
    }

    private func cleanup() {
        let pendingCompletion = completion
        assetWriter = nil
        videoInput = nil
        adaptor = nil
        completion = nil
        isSessionStarted = false
        // Ensure the caller always gets a callback if it wasn't already fired
        if pendingCompletion != nil {
            DispatchQueue.main.async { pendingCompletion?(nil) }
        }
    }
}
