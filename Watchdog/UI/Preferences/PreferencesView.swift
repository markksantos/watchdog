import SwiftUI
import ServiceManagement
import AVFoundation

struct PreferencesView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @EnvironmentObject var captureStore: CaptureStore
    @State private var showPaywall = false
    @State private var alarmTesting = false
    @State private var loginItemError: String?
    @State private var showRecordingNotice = false
    @State private var confirmDeleteAll = false

    var body: some View {
        Form {
            detectionSection
            captureSection
            schedulingSection
            generalSection
            securityResponseSection
            privacySection
            subscriptionSection
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 780)
        .navigationTitle("Preferences")
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .environmentObject(subscriptionManager)
        }
        .alert("Launch at Login", isPresented: .init(
            get: { loginItemError != nil },
            set: { if !$0 { loginItemError = nil } }
        )) {
            Button("OK") { loginItemError = nil }
        } message: {
            Text(loginItemError ?? "")
        }
        .sheet(isPresented: $showRecordingNotice) {
            RecordingNoticeView(isReview: true)
                .environmentObject(settingsManager)
        }
        .alert("Delete all captures?", isPresented: $confirmDeleteAll) {
            Button("Delete All", role: .destructive) { captureStore.deleteAllCaptures() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This permanently deletes every saved image and video clip from \(settingsManager.saveLocation). This cannot be undone.")
        }

        // Footer
        VStack(spacing: 4) {
            Text("Watchdog v1.0.0")
                .font(.caption)
                .foregroundColor(.secondary)
            Text("Note: Camera LED is hardware-controlled on Apple Silicon and cannot be disabled.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.bottom, 12)
        .padding(.horizontal, 24)
    }

    // MARK: - Detection Section

    private var detectionSection: some View {
        Section("Detection") {
            Picker("Camera", selection: $settingsManager.selectedCameraID) {
                Text("Default").tag("")
                ForEach(CameraManager.availableCameras, id: \.uniqueID) { device in
                    Text(device.localizedName).tag(device.uniqueID)
                }
            }

            Picker("Detection Mode", selection: $settingsManager.detectionMode) {
                ForEach(DetectionMode.allCases, id: \.self) { mode in
                    Label(mode.rawValue, systemImage: mode.icon)
                        .tag(mode)
                }
            }

            Picker("Capture Interval", selection: $settingsManager.captureInterval) {
                ForEach(CaptureInterval.allCases, id: \.self) { interval in
                    Text(interval.label).tag(interval)
                }
            }
            .disabled(settingsManager.detectionMode != .alwaysOn)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Motion Sensitivity")
                    Spacer()
                    Text(String(format: "%.2f", settingsManager.motionSensitivity))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
                Slider(value: $settingsManager.motionSensitivity, in: 0.01...0.20, step: 0.01)
                HStack {
                    Text("More Sensitive")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("Less Sensitive")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .disabled(settingsManager.detectionMode != .motionDetection)
        }
    }

    // MARK: - Capture Section

    private var captureSection: some View {
        Section("Capture") {
            HStack {
                Text("Save Location")
                Spacer()
                Text(settingsManager.saveLocation)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 200, alignment: .trailing)

                Button("Browse...") {
                    let panel = NSOpenPanel()
                    panel.canChooseDirectories = true
                    panel.canChooseFiles = false
                    panel.canCreateDirectories = true
                    panel.prompt = "Select"
                    panel.directoryURL = URL(fileURLWithPath: settingsManager.saveLocation)
                    if panel.runModal() == .OK, let url = panel.url {
                        // Routed through SettingsManager so a security-scoped bookmark is
                        // stored — a bare path grants no access on the next launch.
                        settingsManager.setSaveLocation(url)
                    }
                }
                .controlSize(.small)
            }

            Picker("Photo Quality", selection: $settingsManager.photoQuality) {
                ForEach(PhotoQuality.allCases, id: \.self) { quality in
                    Text(quality.rawValue).tag(quality)
                }
            }

            if subscriptionManager.hasAccess(to: .videoRecording) {
                Toggle("Video Recording", isOn: $settingsManager.videoRecordingEnabled)
            } else {
                proFeatureLock(feature: .videoRecording)
            }
        }
    }

    // MARK: - Scheduling Section

    private var schedulingSection: some View {
        Section("Detection Schedule") {
            if subscriptionManager.hasAccess(to: .detectionScheduling) {
                Toggle("Enable Scheduling", isOn: $settingsManager.scheduleConfig.isEnabled)

                if settingsManager.scheduleConfig.isEnabled {
                    Picker("Start Time", selection: $settingsManager.scheduleConfig.startHour) {
                        ForEach(0..<24, id: \.self) { hour in
                            Text(formatHour(hour)).tag(hour)
                        }
                    }

                    Picker("End Time", selection: $settingsManager.scheduleConfig.endHour) {
                        ForEach(0..<24, id: \.self) { hour in
                            Text(formatHour(hour)).tag(hour)
                        }
                    }

                    HStack {
                        ForEach(Weekday.allCases) { day in
                            Button(day.shortName) {
                                if settingsManager.scheduleConfig.activeWeekdays.contains(day) {
                                    settingsManager.scheduleConfig.activeWeekdays.remove(day)
                                } else {
                                    settingsManager.scheduleConfig.activeWeekdays.insert(day)
                                }
                            }
                            .buttonStyle(.bordered)
                            .tint(settingsManager.scheduleConfig.activeWeekdays.contains(day) ? .accentColor : .secondary)
                            .controlSize(.small)
                            .disabled(
                                settingsManager.scheduleConfig.activeWeekdays.contains(day) &&
                                settingsManager.scheduleConfig.activeWeekdays.count == 1
                            )
                        }
                    }

                    Text("Active: \(settingsManager.scheduleConfig.formattedTimeRange)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                proFeatureLock(feature: .detectionScheduling)
            }
        }
    }

    // MARK: - General Section

    private var generalSection: some View {
        Section("General") {
            Toggle("Enable Notifications", isOn: $settingsManager.notificationsEnabled)
            Toggle("Launch at Login", isOn: Binding(
                get: { settingsManager.launchAtLogin },
                set: { newValue in
                    settingsManager.launchAtLogin = newValue
                    do {
                        if newValue {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                    } catch {
                        print("[Watchdog] Launch at login error: \(error)")
                        settingsManager.launchAtLogin = !newValue
                        loginItemError = "Failed to \(newValue ? "enable" : "disable") launch at login. The app must be in your Applications folder and properly signed."
                    }
                }
            ))

            VStack(alignment: .leading, spacing: 2) {
                Toggle("Prevent System Sleep", isOn: $settingsManager.preventSleep)
                Text("Keeps your Mac awake while Watchdog is running so monitoring is never interrupted.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Toggle("Prevent Screen Lock", isOn: $settingsManager.preventScreenLock)
                Text("Keeps the display on and prevents auto-lock. Useful if you need the camera to stay active.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Security Response Section

    private var securityResponseSection: some View {
        Section("Security Response") {
            // Alarm Siren
            if subscriptionManager.hasAccess(to: .alarmSiren) {
                Toggle("Alarm Siren", isOn: $settingsManager.alarmEnabled)

                if settingsManager.alarmEnabled {
                    Picker("Sound", selection: $settingsManager.alarmSound) {
                        ForEach(AlarmSound.allCases, id: \.self) { sound in
                            Text(sound.rawValue).tag(sound)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Volume")
                            Spacer()
                            Text(String(format: "%.0f%%", settingsManager.alarmVolume * 100))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                        }
                        Slider(value: $settingsManager.alarmVolume, in: 0.0...1.0, step: 0.05)
                    }

                    Button(alarmTesting ? "Playing..." : "Test Alarm") {
                        alarmTesting = true
                        AlarmManager.shared.test()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.1) {
                            alarmTesting = false
                        }
                    }
                    .controlSize(.small)
                    .disabled(alarmTesting)
                }
            } else {
                proFeatureLock(feature: .alarmSiren)
            }

            // Flash Alert
            if subscriptionManager.hasAccess(to: .flashAlert) {
                Toggle("Flash Alert", isOn: $settingsManager.flashAlertEnabled)
            } else {
                proFeatureLock(feature: .flashAlert)
            }

            // Screen Dim
            if subscriptionManager.hasAccess(to: .screenDim) {
                Toggle("Dim Screen While Monitoring", isOn: $settingsManager.screenDimEnabled)

                if settingsManager.screenDimEnabled {
                    Text("Covers the desktop so it isn't visible to the room. Press ⌘⇧L or click Restore Screen to lift it; it also lifts on its own after 15 minutes. Watchdog stays in the menu bar and all system shortcuts keep working.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                proFeatureLock(feature: .screenDim)
            }
        }
    }

    // MARK: - Privacy Section

    /// Guideline 5.1.1 expects the privacy policy to be reachable from inside the app, and
    /// users need a direct way to erase what Watchdog has recorded of them and others.
    private var privacySection: some View {
        Section("Privacy") {
            HStack {
                Text("Capture Retention")
                Spacer()
                Text(settingsManager.isPaid
                     ? "Kept until you delete them"
                     : "Deleted automatically after 3 days")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Button("Review What Watchdog Records...") {
                showRecordingNotice = true
            }

            Button("Delete All Captures...", role: .destructive) {
                confirmDeleteAll = true
            }
            .disabled(captureStore.captures.isEmpty)

            HStack(spacing: 6) {
                Link("Privacy Policy", destination: URL(string: LegalLinks.privacyPolicy)!)
                Text("·").foregroundColor(.secondary)
                Link("Terms of Use", destination: URL(string: LegalLinks.termsOfUse)!)
                Text("·").foregroundColor(.secondary)
                Link("Support", destination: URL(string: LegalLinks.support)!)
            }
            .font(.caption)
        }
    }

    // MARK: - Subscription Section

    private var subscriptionSection: some View {
        Section("Subscription") {
            let status = subscriptionManager.status
            switch status {
            case .subscribed(_, let expiresDate):
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Pro")
                            .font(.headline)
                        Text("Expires: \(expiresDate.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
            case .trial(let daysRemaining):
                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Trial")
                            .font(.headline)
                        Text("\(daysRemaining) day\(daysRemaining == 1 ? "" : "s") remaining — all features unlocked")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
            case .free, .expired:
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: status == .expired ? "exclamationmark.triangle" : "hourglass")
                            .foregroundColor(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(status == .expired ? "Trial Expired" : "Free Plan")
                                .font(.headline)
                            Text("3-day capture history")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }

                    Button(action: { showPaywall = true }) {
                        HStack {
                            Image(systemName: "star.fill")
                            Text("Upgrade to Pro")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .controlSize(.large)
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    // MARK: - Pro Feature Lock

    @ViewBuilder
    private func proFeatureLock(feature: ProFeature) -> some View {
        Button(action: { showPaywall = true }) {
            HStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .foregroundColor(.secondary)
                Image(systemName: feature.icon)
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(feature.rawValue)
                        .font(.callout)
                    Text(feature.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text("PRO")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor)
                    .clipShape(Capsule())
            }
        }
        .buttonStyle(.plain)
    }

    private func formatHour(_ hour: Int) -> String {
        let period = hour >= 12 ? "PM" : "AM"
        let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        return "\(displayHour) \(period)"
    }
}
