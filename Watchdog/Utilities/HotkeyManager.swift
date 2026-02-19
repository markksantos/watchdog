import Foundation
import AppKit
import Carbon.HIToolbox

class HotkeyManager {
    static let shared = HotkeyManager()

    private var monitors: [Any] = []
    private weak var detectionEngine: DetectionEngine?

    private init() {}

    func configure(detectionEngine: DetectionEngine) {
        self.detectionEngine = detectionEngine
        registerHotkeys()
    }

    private func registerHotkeys() {
        guard monitors.isEmpty else { return }

        // ⌘⇧M — Toggle monitoring
        let monitorToggle = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.modifierFlags.contains([.command, .shift]),
                  event.keyCode == UInt16(kVK_ANSI_M) else { return }
            self?.toggleMonitoring()
        }
        if let monitorToggle { monitors.append(monitorToggle) }

        // ⌘⇧C — Manual capture
        let captureHotkey = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.modifierFlags.contains([.command, .shift]),
                  event.keyCode == UInt16(kVK_ANSI_C) else { return }
            self?.manualCapture()
        }
        if let captureHotkey { monitors.append(captureHotkey) }

        // Also monitor local events (when app is in foreground)
        let localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains([.command, .shift]) {
                if event.keyCode == UInt16(kVK_ANSI_M) {
                    self?.toggleMonitoring()
                    return nil
                } else if event.keyCode == UInt16(kVK_ANSI_C) {
                    self?.manualCapture()
                    return nil
                }
            }
            return event
        }
        if let localMonitor { monitors.append(localMonitor) }
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
        for monitor in monitors {
            NSEvent.removeMonitor(monitor)
        }
    }
}
