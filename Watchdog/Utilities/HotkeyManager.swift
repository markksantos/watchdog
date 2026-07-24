import Foundation
import AppKit
import Carbon.HIToolbox

/// In-app keyboard shortcuts.
///
/// These are deliberately **local only**. System-wide key monitoring
/// (`NSEvent.addGlobalMonitorForEvents(matching: .keyDown)`) requires Accessibility /
/// Input Monitoring trust, which a sandboxed Mac App Store app cannot obtain — the
/// handlers would never fire — and a process-wide keystroke listener is not something a
/// camera app should be installing regardless. Use the menu bar item for the same actions
/// when Watchdog is in the background.
class HotkeyManager {
    static let shared = HotkeyManager()

    private var monitor: Any?
    private weak var detectionEngine: DetectionEngine?

    private init() {}

    func configure(detectionEngine: DetectionEngine) {
        self.detectionEngine = detectionEngine
        registerHotkeys()
    }

    private func registerHotkeys() {
        guard monitor == nil else { return }

        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.modifierFlags.contains([.command, .shift]) else { return event }

            switch Int(event.keyCode) {
            case kVK_ANSI_M:            // ⌘⇧M — toggle monitoring
                self?.toggleMonitoring()
                return nil
            case kVK_ANSI_C:            // ⌘⇧C — manual capture
                self?.manualCapture()
                return nil
            default:
                return event
            }
        }
    }

    private func toggleMonitoring() {
        DispatchQueue.main.async { [weak self] in
            guard let engine = self?.detectionEngine else { return }
            if engine.isMonitoring {
                engine.stopMonitoring()
            } else {
                engine.startMonitoring()
            }
        }
    }

    private func manualCapture() {
        DispatchQueue.main.async { [weak self] in
            self?.detectionEngine?.manualCapture()
        }
    }

    deinit {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
