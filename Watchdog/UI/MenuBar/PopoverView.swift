import SwiftUI

struct PopoverView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var captureStore: CaptureStore
    @EnvironmentObject var detectionEngine: DetectionEngine
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @ObservedObject private var appearance = AppearanceSettings.shared

    @State private var showCameraPermissionAlert = false
    @State private var showRecordingNotice = false

    var openMainWindow: () -> Void
    var openPreferences: () -> Void
    var openPaywall: () -> Void

    private var accent: Color { appearance.accentColor }
    private var isMonitoring: Bool { settingsManager.isMonitoring }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            ScrollView {
                VStack(spacing: 12) {
                    statusCard
                    detectionModeCard
                    lastCaptureCard

                    if !subscriptionManager.isProUser {
                        upgradeButton
                    }
                }
                .padding(12)
            }

            Divider()

            bottomActions
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
        }
        .frame(
            width: WatchdogMetrics.popoverWidth,
            height: WatchdogMetrics.popoverHeight
        )
        .alert("Camera Access Required", isPresented: $showCameraPermissionAlert) {
            Button("Open System Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
                    NSWorkspace.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Watchdog needs camera access to monitor for detections. Please enable it in System Settings → Privacy & Security → Camera.")
        }
        .onReceive(detectionEngine.$cameraPermissionDenied) { denied in
            if denied { showCameraPermissionAlert = true }
        }
        // Monitoring is refused until the user has acknowledged what Watchdog records.
        .onReceive(detectionEngine.$needsRecordingConsent) { needed in
            if needed { showRecordingNotice = true }
        }
        .sheet(isPresented: $showRecordingNotice, onDismiss: {
            detectionEngine.needsRecordingConsent = false
            // Proceed straight into monitoring if they accepted.
            if settingsManager.hasAcceptedRecordingNotice {
                detectionEngine.startMonitoring()
            }
        }) {
            RecordingNoticeView()
                .environmentObject(settingsManager)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "eye.fill")
                .font(.system(size: 16))
                .foregroundColor(accent)

            Text("Watchdog")
                .font(.system(size: 14, weight: .semibold))

            subscriptionBadge

            Spacer()

            HStack(spacing: 5) {
                Circle()
                    .fill(isMonitoring ? WatchdogColor.live : Color.secondary.opacity(0.5))
                    .frame(width: 7, height: 7)
                Text(isMonitoring ? "Live" : "Idle")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(isMonitoring ? WatchdogColor.live : .secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var subscriptionBadge: some View {
        switch subscriptionManager.status {
        case .subscribed:
            badge("PRO", color: WatchdogColor.pro)
        case .trial(let days):
            badge("TRIAL · \(days)D", color: WatchdogColor.warn)
        case .free, .expired:
            EmptyView()
        }
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(color))
    }

    // MARK: - Status

    private var statusCard: some View {
        VStack(spacing: 10) {
            Toggle(isOn: Binding(
                get: { isMonitoring },
                set: { $0 ? detectionEngine.startMonitoring() : detectionEngine.stopMonitoring() }
            )) {
                HStack(spacing: 8) {
                    Image(systemName: isMonitoring ? "video.fill" : "video.slash.fill")
                        .font(.system(size: 13))
                        .foregroundColor(isMonitoring ? WatchdogColor.live : .secondary)
                    Text("Monitoring")
                        .font(.system(size: 13, weight: .medium))
                    Spacer()
                }
            }
            .toggleStyle(.switch)
            .tint(WatchdogColor.live)

            if isMonitoring {
                Button(action: { detectionEngine.manualCapture() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "camera.shutter.button")
                        Text("Capture Now")
                    }
                    .frame(maxWidth: .infinity)
                }
                .controlSize(.small)
                .buttonStyle(.borderedProminent)
                .tint(accent)
            }

            if settingsManager.scheduleConfig.isEnabled {
                HStack(spacing: 6) {
                    Image(systemName: "clock.badge.checkmark")
                        .font(.system(size: 10))
                    Text("Scheduled \(settingsManager.scheduleConfig.formattedTimeRange)")
                        .font(.system(size: 11))
                    Spacer()
                }
                .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: WatchdogMetrics.cardCornerRadius)
                .fill(WatchdogColor.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: WatchdogMetrics.cardCornerRadius)
                .strokeBorder(
                    isMonitoring ? WatchdogColor.live.opacity(0.4) : WatchdogColor.cardBorder,
                    lineWidth: 1
                )
        )
    }

    // MARK: - Detection mode

    /// Previously an AppKit segmented picker carrying full-length labels inside a 320pt
    /// popover, which clipped the outer segments at both edges. Equal-width pills with short
    /// names fit the space and degrade by shrinking text rather than cutting it off.
    private var detectionModeCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DETECTION MODE")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
                .kerning(0.4)

            SegmentedPills(
                options: DetectionMode.allCases,
                selection: $settingsManager.detectionMode,
                accent: accent,
                maxPerRow: 3
            ) { mode in
                IconPillLabel(symbol: mode.icon, title: mode.shortName)
            }
        }
    }

    // MARK: - Last capture

    private var lastCaptureCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("LAST CAPTURE")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
                    .kerning(0.4)
                Spacer()
                if captureStore.todayCount > 0 {
                    Text("\(captureStore.todayCount) today")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }

            HStack(spacing: 10) {
                if let lastCapture = captureStore.captures.first,
                   let nsImage = NSImage(contentsOf: lastCapture.imageURL) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 68, height: 68)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(lastCapture.shortTimestamp)
                            .font(.system(size: 12, weight: .medium))
                        Label(lastCapture.detectionType.rawValue, systemImage: lastCapture.detectionType.icon)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                } else {
                    placeholderThumbnail
                    Text("No captures yet")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            Button(action: openMainWindow) {
                HStack(spacing: 6) {
                    Image(systemName: "photo.on.rectangle.angled")
                    Text("View All Captures")
                }
                .frame(maxWidth: .infinity)
            }
            .controlSize(.small)
        }
    }

    private var placeholderThumbnail: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.secondary.opacity(0.12))
            .frame(width: 68, height: 68)
            .overlay(
                Image(systemName: "camera")
                    .font(.system(size: 18))
                    .foregroundColor(.secondary)
            )
    }

    // MARK: - Upgrade

    private var upgradeButton: some View {
        Button(action: openPaywall) {
            HStack(spacing: 6) {
                Image(systemName: "star.fill")
                Text("Upgrade to Pro")
            }
            .frame(maxWidth: .infinity)
        }
        .controlSize(.small)
        .buttonStyle(.borderedProminent)
        .tint(WatchdogColor.pro)
    }

    // MARK: - Bottom actions

    private var bottomActions: some View {
        HStack(spacing: 8) {
            Button(action: openPreferences) {
                HStack(spacing: 5) {
                    Image(systemName: "gearshape.fill")
                    Text("Preferences")
                }
                .frame(maxWidth: .infinity)
            }
            .controlSize(.small)

            Button(role: .destructive, action: {
                NSApplication.shared.terminate(nil)
            }) {
                HStack(spacing: 5) {
                    Image(systemName: "power")
                    Text("Quit")
                }
                .frame(maxWidth: .infinity)
            }
            .controlSize(.small)
        }
    }
}
