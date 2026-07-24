import SwiftUI
import AVFoundation

/// Which camera to use, what triggers a capture, and how touchy the trigger is.
struct CameraTab: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @ObservedObject private var captureSettings = CaptureSettings.shared
    @ObservedObject private var appearance = AppearanceSettings.shared

    /// Cached once — enumerating devices is not free and the list rarely changes mid-session.
    private let cameras = CameraManager.availableCameras

    private var accent: Color { appearance.accentColor }

    private var sensitivityLevel: Binding<Double> {
        Binding(
            get: { Double(MotionSensitivityScale.level(forThreshold: settingsManager.motionSensitivity)) },
            set: { settingsManager.motionSensitivity = MotionSensitivityScale.threshold(forLevel: Int($0)) }
        )
    }

    private var currentLevel: Int {
        MotionSensitivityScale.level(forThreshold: settingsManager.motionSensitivity)
    }

    var body: some View {
        VStack(spacing: 14) {
            cameraCard
            detectionModeCard

            if settingsManager.detectionMode == .motionDetection {
                sensitivityCard
            }

            if settingsManager.detectionMode == .alwaysOn {
                intervalCard
            }
        }
    }

    // MARK: - Camera

    private var cameraCard: some View {
        SettingCard(
            icon: "camera.fill",
            title: "Camera",
            accent: accent,
            info: "Which camera Watchdog watches through. External cameras appear here once macOS recognises them."
        ) {
            Picker("", selection: $settingsManager.selectedCameraID) {
                Text("System Default").tag("")
                ForEach(cameras, id: \.uniqueID) { device in
                    Text(device.localizedName).tag(device.uniqueID)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)

            if cameras.isEmpty {
                TipCallout(
                    text: "No cameras detected. Connect a camera, or grant access in System Settings → Privacy & Security → Camera.",
                    systemImage: "exclamationmark.triangle.fill"
                )
            }
        }
    }

    // MARK: - Detection mode

    private var detectionModeCard: some View {
        SettingCard(
            icon: "viewfinder",
            title: "Detection Mode",
            accent: accent,
            info: "What makes Watchdog take a picture. Changing this while monitoring restarts the detector immediately."
        ) {
            SegmentedPills(
                options: DetectionMode.allCases,
                selection: $settingsManager.detectionMode,
                accent: accent,
                maxPerRow: 3
            ) { mode in
                IconPillLabel(symbol: mode.icon, title: mode.shortName)
            }

            Text(settingsManager.detectionMode.explanation)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Motion sensitivity

    private var sensitivityCard: some View {
        SettingCard(
            icon: "waveform",
            title: "Motion Sensitivity",
            accent: accent,
            value: "\(currentLevel)",
            info: "How much of the frame has to change before Watchdog captures. Higher is more sensitive — and more likely to fire on shadows and lighting changes."
        ) {
            Slider(value: sensitivityLevel, in: 1...10, step: 1)
                .tint(WatchdogColor.toggle)

            HStack(spacing: 6) {
                Image(systemName: "tortoise.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Text("Less Sensitive")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                Spacer()

                Text("More Sensitive")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Image(systemName: "hare.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            if appearance.showTips {
                TipCallout(text: MotionSensitivityScale.example(forLevel: currentLevel))
            }
        }
    }

    // MARK: - Capture interval

    private var intervalCard: some View {
        SettingCard(
            icon: "timer",
            title: "Capture Interval",
            accent: accent,
            value: captureSettings.intervalLabel,
            info: "How long Watchdog waits between shots in Always-On mode. Shorter intervals fill your disk faster."
        ) {
            SegmentedPills(
                options: IntervalPreset.allCases.map(\.rawValue) + [-1],
                selection: Binding(
                    get: {
                        IntervalPreset(rawValue: captureSettings.intervalSeconds) != nil
                            ? captureSettings.intervalSeconds
                            : -1
                    },
                    set: { newValue in
                        // -1 is the Custom pill; leave the stored value alone so the stepper
                        // below keeps whatever the user last typed.
                        if newValue != -1 { captureSettings.intervalSeconds = newValue }
                    }
                ),
                accent: accent,
                maxPerRow: 7
            ) { seconds in
                Text(seconds == -1 ? "Custom" : (IntervalPreset(rawValue: seconds)?.label ?? "\(seconds)s"))
            }

            if IntervalPreset(rawValue: captureSettings.intervalSeconds) == nil {
                LabelledRow(title: "Every") {
                    HStack(spacing: 6) {
                        TextField(
                            "",
                            value: Binding(
                                get: { captureSettings.intervalSeconds },
                                set: { captureSettings.intervalSeconds = $0 }
                            ),
                            format: .number
                        )
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 70)
                        .multilineTextAlignment(.trailing)

                        Text("seconds")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)

                        Stepper(
                            "",
                            value: Binding(
                                get: { captureSettings.intervalSeconds },
                                set: { captureSettings.intervalSeconds = $0 }
                            ),
                            in: CaptureSettings.intervalRange
                        )
                        .labelsHidden()
                    }
                }

                Text("Between \(CaptureSettings.intervalRange.lowerBound) second and \(CaptureSettings.intervalRange.upperBound / 60) minutes.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
    }
}
