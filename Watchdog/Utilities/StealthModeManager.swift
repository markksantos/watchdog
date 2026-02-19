import AppKit
import Combine

class StealthModeManager {
    static let shared = StealthModeManager()

    private var windows: [NSWindow] = []
    private var cancellables = Set<AnyCancellable>()

    private init() {
        Publishers.CombineLatest(
            SettingsManager.shared.$isMonitoring,
            SettingsManager.shared.$stealthModeEnabled
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] isMonitoring, stealthEnabled in
            if isMonitoring && stealthEnabled {
                self?.enable()
            } else {
                self?.disable()
            }
        }
        .store(in: &cancellables)
    }

    func enable() {
        guard windows.isEmpty else { return }

        for screen in NSScreen.screens {
            let win = makeWindow(for: screen)
            win.orderFront(nil)
            windows.append(win)
        }

        NSApplication.shared.activate(ignoringOtherApps: true)
        windows.first?.makeKey()
    }

    func disable() {
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
    }

    private func makeWindow(for screen: NSScreen) -> NSWindow {
        let win = NSWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false,
            screen: screen
        )
        win.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)))
        win.backgroundColor = .black
        win.isOpaque = true
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let view = StealthView(manager: self)
        win.contentView = view
        return win
    }
}

private class StealthView: NSView {
    weak var manager: StealthModeManager?
    private let label = NSTextField(labelWithString: "Watchdog is monitoring — press ⌘⇧L to reveal")

    init(manager: StealthModeManager) {
        self.manager = manager
        super.init(frame: .zero)

        label.textColor = NSColor.white.withAlphaComponent(0.4)
        label.font = NSFont.systemFont(ofSize: 13)
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        // ⌘⇧L — key code 37 is 'L'
        if event.keyCode == 37,
           event.modifierFlags.contains(.command),
           event.modifierFlags.contains(.shift) {
            manager?.disable()
        }
        // Swallow all other key events to prevent app switching
    }

    // Intercept performKeyEquivalent to block Cmd shortcuts
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.keyCode == 37,
           event.modifierFlags.contains(.command),
           event.modifierFlags.contains(.shift) {
            manager?.disable()
            return true
        }
        return true // Block all other Cmd shortcuts
    }
}
