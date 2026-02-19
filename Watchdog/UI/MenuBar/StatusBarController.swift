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

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        popover = NSPopover()

        configurePopover()
        configureButton()
        observeMonitoringState()
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

        popover.contentSize = NSSize(width: 320, height: 460)
        popover.behavior = .semitransient
        popover.contentViewController = NSHostingController(rootView: popoverView)
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }
        let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        let image = NSImage(systemSymbolName: "eye.fill", accessibilityDescription: "Watchdog")?
            .withSymbolConfiguration(config)
        image?.isTemplate = true
        button.image = image
        button.action = #selector(togglePopover)
        button.target = self
        updateIcon(isMonitoring: settingsManager.isMonitoring)
    }

    private func observeMonitoringState() {
        settingsManager.$isMonitoring
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isMonitoring in
                self?.updateIcon(isMonitoring: isMonitoring)
            }
            .store(in: &cancellables)
    }

    private func updateIcon(isMonitoring: Bool) {
        guard let button = statusItem.button else { return }
        let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)

        if isMonitoring {
            // Green tinted icon when monitoring
            let image = NSImage(systemSymbolName: "eye.fill", accessibilityDescription: "Watchdog")?
                .withSymbolConfiguration(config)
            image?.isTemplate = false
            let coloredImage = image?.image(with: .systemGreen)
            button.image = coloredImage
        } else {
            // Template image — macOS auto-adapts to light/dark menu bar
            let image = NSImage(systemSymbolName: "eye.fill", accessibilityDescription: "Watchdog")?
                .withSymbolConfiguration(config)
            image?.isTemplate = true
            button.image = image
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

        let hostingController = NSHostingController(rootView: preferencesView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Preferences"
        window.setContentSize(NSSize(width: 480, height: 780))
        window.styleMask = [.titled, .closable]
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
