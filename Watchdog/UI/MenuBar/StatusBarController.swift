import Foundation
import AppKit
import SwiftUI
import Combine

class StatusBarController {
    private var statusItem: NSStatusItem
    private var popover: NSPopover
    private var eventMonitor: Any?

    let settingsManager: SettingsManager
    let captureStore: CaptureStore
    let detectionEngine: DetectionEngine
    let subscriptionManager: SubscriptionManager

    private var cancellables = Set<AnyCancellable>()
    private weak var mainWindow: NSWindow?
    private weak var preferencesWindow: NSWindow?
    private weak var paywallWindow: NSWindow?

    init(settingsManager: SettingsManager, captureStore: CaptureStore, detectionEngine: DetectionEngine, subscriptionManager: SubscriptionManager) {
        self.settingsManager = settingsManager
        self.captureStore = captureStore
        self.detectionEngine = detectionEngine
        self.subscriptionManager = subscriptionManager

        // Variable length so the optional capture count has room; the glyph alone still
        // renders at its natural square width.
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        popover = NSPopover()

        configurePopover()
        configureButton()
        observeMonitoringState()
        AppearanceSettings.shared.applyTheme()
    }

    private func configurePopover() {
        let popoverView = PopoverView(openMainWindow: { [weak self] in
            self?.openMainWindow()
        }, openPreferences: { [weak self] in
            self?.openPreferences()
        }, openPaywall: { [weak self] in
            self?.openPaywall()
        })
        .environmentObject(settingsManager)
        .environmentObject(captureStore)
        .environmentObject(detectionEngine)
        .environmentObject(subscriptionManager)

        // Shared with `PopoverView.frame`. These were two independent literals, which is how
        // the popover's content ended up wider than the window hosting it.
        popover.contentSize = NSSize(
            width: WatchdogMetrics.popoverWidth,
            height: WatchdogMetrics.popoverHeight
        )
        popover.behavior = .semitransient
        popover.contentViewController = NSHostingController(rootView: popoverView)
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }
        button.action = #selector(togglePopover)
        button.target = self
        button.imagePosition = .imageLeading
        button.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        updateIcon()
    }

    private func observeMonitoringState() {
        settingsManager.$isMonitoring
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateIcon() }
            .store(in: &cancellables)

        // The glyph, and whether the capture count is shown, are both user preferences.
        let appearance = AppearanceSettings.shared
        appearance.$menuBarIcon
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateIcon() }
            .store(in: &cancellables)

        appearance.$showMenuBarCount
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateIcon() }
            .store(in: &cancellables)

        captureStore.$captures
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard AppearanceSettings.shared.showMenuBarCount else { return }
                self?.updateIcon()
            }
            .store(in: &cancellables)
    }

    /// Redraws the menu bar item for the current monitoring state and appearance preferences.
    ///
    /// The item itself is never hidden — only its glyph changes — because concealing that the
    /// camera may be recording is both dishonest and an App Review failure.
    private func updateIcon() {
        guard let button = statusItem.button else { return }

        let isMonitoring = settingsManager.isMonitoring
        let style = AppearanceSettings.shared.menuBarIcon
        let symbolName = isMonitoring ? style.activeSymbol : style.idleSymbol
        let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)

        let image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: isMonitoring ? "Watchdog — monitoring" : "Watchdog — idle"
        )?.withSymbolConfiguration(config)

        if isMonitoring {
            // Green while the camera is live, matching the palette's "live" token.
            image?.isTemplate = false
            button.image = image?.image(with: .systemGreen)
        } else {
            // Template image — macOS adapts it to a light or dark menu bar automatically.
            image?.isTemplate = true
            button.image = image
        }

        if AppearanceSettings.shared.showMenuBarCount {
            let count = captureStore.todayCount
            button.title = count > 0 ? " \(count)" : ""
        } else {
            button.title = ""
        }
    }

    @objc private func togglePopover() {
        if popover.isShown {
            closePopover()
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closePopover()
        }
    }

    private func closePopover() {
        popover.performClose(nil)
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    func openPreferences() {
        closePopover()

        if let existing = preferencesWindow, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let preferencesView = PreferencesView()
            .environmentObject(settingsManager)
            .environmentObject(subscriptionManager)
            .environmentObject(captureStore)

        let hostingController = NSHostingController(rootView: preferencesView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Preferences"
        window.setContentSize(NSSize(
            width: WatchdogMetrics.preferencesWidth,
            height: WatchdogMetrics.preferencesHeight
        ))
        window.styleMask = [.titled, .closable, .resizable]
        window.minSize = NSSize(width: WatchdogMetrics.preferencesWidth, height: 460)
        window.center()
        window.makeKeyAndOrderFront(nil)
        preferencesWindow = window

        NSApp.activate(ignoringOtherApps: true)
    }

    func openPaywall() {
        closePopover()

        if let existing = paywallWindow, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let paywallView = PaywallView()
            .environmentObject(subscriptionManager)

        let hostingController = NSHostingController(rootView: paywallView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Upgrade to Pro"
        window.setContentSize(NSSize(width: 480, height: 680))
        window.styleMask = [.titled, .closable]
        window.center()
        window.makeKeyAndOrderFront(nil)
        paywallWindow = window

        NSApp.activate(ignoringOtherApps: true)
    }

    func openMainWindow() {
        closePopover()

        if let existing = mainWindow, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let mainWindowView = MainWindowView()
            .environmentObject(settingsManager)
            .environmentObject(captureStore)
            .environmentObject(subscriptionManager)
            .environmentObject(detectionEngine)

        let hostingController = NSHostingController(rootView: mainWindowView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Watchdog"
        window.setContentSize(NSSize(width: 800, height: 600))
        window.styleMask = [.titled, .closable, .resizable, .miniaturizable]
        window.minSize = NSSize(width: 600, height: 400)
        window.center()
        window.makeKeyAndOrderFront(nil)
        mainWindow = window

        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - NSImage Color Tinting

private extension NSImage {
    func image(with tintColor: NSColor) -> NSImage {
        guard let image = self.copy() as? NSImage else { return self }
        image.lockFocus()
        tintColor.set()
        let imageRect = NSRect(origin: .zero, size: image.size)
        imageRect.fill(using: .sourceAtop)
        image.unlockFocus()
        return image
    }
}
