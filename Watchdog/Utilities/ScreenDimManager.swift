import AppKit
import Combine

/// Dims the screen while monitoring is active, so an unattended Mac isn't showing its
/// contents to the room.
///
/// This deliberately does **not** hide Watchdog, block the user in, or suppress the macOS
/// camera indicator:
///   - the menu bar item stays visible the whole time
///   - ⌘Q, ⌘Tab, ⌘⇧Escape and every other system shortcut keep working
///   - a visible, always-present button dismisses the overlay
///   - the overlay times out on its own after `autoDismissInterval`
///
/// Apps that trap the user behind an inescapable window are rejected under App Review
/// guideline 2.4.5, and an overlay that concealed an active camera would be worse than
/// that. Keep all four of the above properties if you touch this file.
class ScreenDimManager {
    static let shared = ScreenDimManager()

    /// The overlay lifts itself after this long even if the user does nothing.
    private let autoDismissInterval: TimeInterval = 15 * 60

    private var windows: [NSWindow] = []
    private var dismissTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    private init() {
        Publishers.CombineLatest(
            SettingsManager.shared.$isMonitoring,
            SettingsManager.shared.$screenDimEnabled
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] isMonitoring, dimEnabled in
            if isMonitoring && dimEnabled {
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

        dismissTimer?.invalidate()
        dismissTimer = Timer.scheduledTimer(withTimeInterval: autoDismissInterval, repeats: false) { [weak self] _ in
            self?.disable()
        }
    }

    func disable() {
        dismissTimer?.invalidate()
        dismissTimer = nil
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

        // Above normal windows, but below the screen saver and below system UI such as
        // the menu bar — the user must always be able to see and reach the system.
        win.level = .floating
        win.backgroundColor = .black
        win.isOpaque = false
        win.alphaValue = 0.92
        win.ignoresMouseEvents = false
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]

        win.contentView = DimView(manager: self)
        return win
    }
}

private class DimView: NSView {
    weak var manager: ScreenDimManager?

    private let label = NSTextField(labelWithString: "Watchdog is monitoring. The camera is active.")
    /// No keyboard shortcut is advertised here. A borderless window cannot become key, so
    /// `keyDown` below never fires for it, and a sandboxed app cannot register a global
    /// hotkey — any shortcut printed here would be a promise the app cannot keep. The
    /// button is the dismissal affordance, backed by the 15-minute timeout.
    private let hint = NSTextField(labelWithString: "The screen restores automatically after 15 minutes.")
    private let button = NSButton(title: "Restore Screen", target: nil, action: nil)

    init(manager: ScreenDimManager) {
        self.manager = manager
        super.init(frame: .zero)

        label.textColor = NSColor.white.withAlphaComponent(0.75)
        label.font = NSFont.systemFont(ofSize: 15, weight: .medium)
        label.alignment = .center

        hint.textColor = NSColor.white.withAlphaComponent(0.4)
        hint.font = NSFont.systemFont(ofSize: 12)
        hint.alignment = .center

        button.target = self
        button.action = #selector(restore)
        button.bezelStyle = .rounded
        button.controlSize = .large

        let stack = NSStackView(views: [label, hint, button])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func restore() {
        manager?.disable()
    }

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        // Never swallow key events: the user must always be able to quit, switch apps, or
        // reach the menu bar. (In practice this is unreachable — the host window is
        // borderless and so can never become key — which is exactly why no keyboard
        // shortcut is advertised on the overlay.)
        super.keyDown(with: event)
    }
}
