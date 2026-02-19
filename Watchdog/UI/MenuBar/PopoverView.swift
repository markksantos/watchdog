import SwiftUI

struct PopoverView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var captureStore: CaptureStore
    @EnvironmentObject var detectionEngine: DetectionEngine
    @EnvironmentObject var subscriptionManager: SubscriptionManager

    @State private var showPaywall = false
    @State private var showCameraPermissionAlert = false

    var openMainWindow: () -> Void
    var openPreferences: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

            Divider()

            // Monitoring toggle
            monitoringToggle
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

            // Manual capture button
            if settingsManager.isMonitoring {
                Button(action: { detectionEngine.manualCapture() }) {
                    HStack {
                        Image(systemName: "camera.shutter.button")
                        Text("Capture Now")
                    }
                    .frame(maxWidth: .infinity)
                }
                .controlSize(.small)
                .buttonStyle(.bordered)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }

            // Schedule status
            if settingsManager.scheduleConfig.isEnabled {
                scheduleStatus
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }

            Divider()

            // Last capture preview
            lastCapturePreview
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

            Divider()

            // Detection mode
            detectionModePicker
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

            Divider()

            // Upgrade button for free users
            if !subscriptionManager.isProUser {
                upgradeButton
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)

                Divider()
            }

            Spacer()

            // Bottom actions
            bottomActions
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
        }
        .frame(width: 320, height: 460)
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .environmentObject(subscriptionManager)
        }
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
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "eye.fill")
                .font(.title2)
                .foregroundColor(.accentColor)
            Text("Watchdog")
                .font(.headline)

            subscriptionBadge

            Spacer()
            Circle()
                .fill(settingsManager.isMonitoring ? Color.green : Color.gray)
                .frame(width: 8, height: 8)
        }
    }

    @ViewBuilder
    private var subscriptionBadge: some View {
        switch subscriptionManager.status {
        case .subscribed:
            Text("PRO")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.blue)
                .clipShape(Capsule())
        case .trial:
            Text("TRIAL")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.orange)
                .clipShape(Capsule())
        case .free, .expired:
            EmptyView()
        }
    }

    // MARK: - Schedule Status

    private var scheduleStatus: some View {
        HStack(spacing: 6) {
            Image(systemName: "clock.badge.checkmark")
                .font(.caption)
                .foregroundColor(.secondary)
            Text("Scheduled: \(settingsManager.scheduleConfig.formattedTimeRange)")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    // MARK: - Monitoring Toggle

    private var monitoringToggle: some View {
        Toggle(isOn: Binding(
            get: { settingsManager.isMonitoring },
            set: { newValue in
                if newValue {
                    detectionEngine.startMonitoring()
                } else {
                    detectionEngine.stopMonitoring()
                }
            }
        )) {
            HStack(spacing: 8) {
                Image(systemName: settingsManager.isMonitoring ? "video.fill" : "video.slash.fill")
                    .foregroundColor(settingsManager.isMonitoring ? .green : .secondary)
                Text("Monitoring")
                    .font(.body)
            }
        }
        .toggleStyle(.switch)
    }

    // MARK: - Last Capture Preview

    private var lastCapturePreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Last Capture")
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                if let lastCapture = captureStore.captures.first {
                    if let nsImage = NSImage(contentsOf: lastCapture.imageURL) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        placeholderThumbnail
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(lastCapture.shortTimestamp)
                            .font(.caption)
                        Label(lastCapture.detectionType.rawValue, systemImage: lastCapture.detectionType.icon)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                } else {
                    placeholderThumbnail

                    Text("No captures yet")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            Button(action: openMainWindow) {
                HStack {
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
            .fill(Color.secondary.opacity(0.15))
            .frame(width: 80, height: 80)
            .overlay(
                Image(systemName: "camera")
                    .font(.title3)
                    .foregroundColor(.secondary)
            )
    }

    // MARK: - Upgrade Button

    private var upgradeButton: some View {
        Button(action: { showPaywall = true }) {
            HStack {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                Text("Upgrade to Pro")
            }
            .frame(maxWidth: .infinity)
        }
        .controlSize(.small)
        .buttonStyle(.borderedProminent)
    }

    // MARK: - Detection Mode Picker

    private var detectionModePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Detection Mode")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Picker("", selection: $settingsManager.detectionMode) {
                ForEach(DetectionMode.allCases, id: \.self) { mode in
                    Label(mode.rawValue, systemImage: mode.icon)
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    // MARK: - Bottom Actions

    private var bottomActions: some View {
        VStack(spacing: 8) {
            Button(action: openPreferences) {
                HStack {
                    Image(systemName: "gear")
                    Text("Preferences...")
                }
                .frame(maxWidth: .infinity)
            }
            .controlSize(.small)

            Button(role: .destructive, action: {
                NSApplication.shared.terminate(nil)
            }) {
                HStack {
                    Image(systemName: "power")
                    Text("Quit Watchdog")
                }
                .frame(maxWidth: .infinity)
            }
            .controlSize(.small)
        }
    }
}
