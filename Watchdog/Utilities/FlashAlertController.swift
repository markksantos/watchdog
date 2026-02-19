import AppKit

class FlashAlertController {
    static let shared = FlashAlertController()

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

    private func present() {
        tearDown()

        for screen in NSScreen.screens {
            let win = makeWindow(for: screen)
            win.orderFront(nil)
            windows.append(win)
        }

        isRed = true
        flashTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.toggleColor()
        }

        dismissTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { [weak self] _ in
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
            win.contentView?.layer?.backgroundColor = color.withAlphaComponent(0.75).cgColor
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
        win.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)) + 1)
        win.backgroundColor = .clear
        win.isOpaque = false
        win.alphaValue = 1.0
        win.ignoresMouseEvents = false
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let view = FlashAlertView(controller: self)
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.systemRed.withAlphaComponent(0.75).cgColor
        win.contentView = view
        return win
    }
}

private class FlashAlertView: NSView {
    weak var controller: FlashAlertController?

    init(controller: FlashAlertController) {
        self.controller = controller
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func mouseDown(with event: NSEvent) {
        controller?.dismiss()
    }

    override func keyDown(with event: NSEvent) {
        controller?.dismiss()
    }

    override var acceptsFirstResponder: Bool { true }
}
