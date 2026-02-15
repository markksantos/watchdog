import Foundation
import AppKit

class WakeDetector {
    static let shared = WakeDetector()

    private var detectionEngine: DetectionEngine?
    private var isBurstCapturing = false

    private init() {}

    func configure(detectionEngine: DetectionEngine) {
        self.detectionEngine = detectionEngine

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleWake(_:)),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleWake(_:)),
            name: NSWorkspace.screensDidWakeNotification,
            object: nil
        )
    }

    @objc private func handleWake(_ notification: Notification) {
        guard !isBurstCapturing else { return }

        isBurstCapturing = true
        print("[Watchdog] Wake detected - starting burst capture")

        detectionEngine?.burstCapture(duration: 10)

        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            self?.isBurstCapturing = false
        }
    }

    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
}
