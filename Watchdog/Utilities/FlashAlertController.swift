import AppKit

/// Tints the screens to signal a detection, so someone standing at the Mac knows they have
/// been noticed.
///
/// The constraints below are not stylistic — an earlier version of this file violated all of
/// them and would have failed review:
///
///   - **It can never block input.** `ignoresMouseEvents` is `true` on every overlay, so
///     clicks, drags and keystrokes pass straight through to whatever is underneath. An
///     overlay that swallows input across all displays traps the user, which is a 2.4.5
///     rejection ("must not interfere with system functionality").
///   - **It stays below system UI.** `.floating` keeps the menu bar, Control Center and the
///     camera indicator reachable and visible. Never raise this above `.screenSaver`.
///   - **It flashes slowly, and not at all under Reduce Motion.** Saturated full-screen
///     flashing near 3 Hz is a photosensitive-seizure risk that Apple does reject on, and
///     WCAG 2.3.1 caps it at three flashes per second. `flashInterval` is deliberately well
///     under that, the tint is translucent rather than saturated, and when the user has
///     asked the system to reduce motion the overlay holds a steady colour instead.
///   - **It always goes away by itself.** `visibleDuration` tears the overlay down whether
///     or not anything else happens.
class FlashAlertController {
    static let shared = FlashAlertController()

    /// Seconds between colour changes. One second per colour is 0.5 flashes/sec of each
    /// hue — a third of the WCAG limit. Do not lower this below ~0.4.
    private let flashInterval: TimeInterval = 1.0

    /// How long the overlay stays up before removing itself.
    private let visibleDuration: TimeInterval = 8.0

    /// Translucent enough to read as an alert tint rather than a blackout, so the user can
    /// still see and use what is behind it.
    private let tintAlpha: CGFloat = 0.28

    private var windows: [NSWindow] = []
    private var flashTimer: Timer?
    private var dismissTimer: Timer?
    private var isRed = true

    private init() {}

    func showAlert() {
        DispatchQueue.main.async { [weak self] in
            self?.present()
        }
    }

    func dismiss() {
        DispatchQueue.main.async { [weak self] in
            self?.tearDown()
        }
    }

    /// Honours the system Reduce Motion setting; when set, the overlay does not alternate.
    private var shouldAnimate: Bool {
        !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    private func present() {
        tearDown()

        for screen in NSScreen.screens {
            let win = makeWindow(for: screen)
            win.orderFront(nil)
            windows.append(win)
        }

        isRed = true
        if shouldAnimate {
            flashTimer = Timer.scheduledTimer(withTimeInterval: flashInterval, repeats: true) { [weak self] _ in
                self?.toggleColor()
            }
        }

        dismissTimer = Timer.scheduledTimer(withTimeInterval: visibleDuration, repeats: false) { [weak self] _ in
            self?.tearDown()
        }
    }

    private func tearDown() {
        flashTimer?.invalidate()
        flashTimer = nil
        dismissTimer?.invalidate()
        dismissTimer = nil
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
    }

    private func toggleColor() {
        isRed.toggle()
        let color = isRed ? NSColor.systemRed : NSColor.systemBlue
        windows.forEach { win in
            win.contentView?.layer?.backgroundColor = color.withAlphaComponent(tintAlpha).cgColor
        }
    }

    private func makeWindow(for screen: NSScreen) -> NSWindow {
        let win = NSWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false,
            screen: screen
        )

        // Above ordinary windows, but below the menu bar, Control Center and the screen
        // saver. The camera indicator must stay visible at all times.
        win.level = .floating
        win.backgroundColor = .clear
        win.isOpaque = false
        win.alphaValue = 1.0

        // The overlay is purely informational: every event passes through to the app
        // underneath, so it cannot stop the user from doing anything.
        win.ignoresMouseEvents = true
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]

        let view = NSView(frame: screen.frame)
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.systemRed.withAlphaComponent(tintAlpha).cgColor
        win.contentView = view
        return win
    }
}
