import SwiftUI

/// What Watchdog does to get your attention when a detection fires.
struct AlertsTab: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @ObservedObject private var appearance = AppearanceSettings.shared

    @State private var alarmTesting = false

    var showPaywall: () -> Void

    private var accent: Color { appearance.accentColor }

    var body: some View {
        VStack(spacing: 14) {
            notificationsCard
            alarmCard
            flashCard
            screenDimCard
        }
    }

    // MARK: - Notifications

    private var notificationsCard: some View {
        SettingCard(
            icon: "bell.fill",
            title: "Notifications",
            accent: accent,
            info: "Posts a macOS notification with a thumbnail each time a capture is taken."
        ) {
            ToggleRow(
                title: "Notify me on each detection",
                subtitle: "Shows the capture as a notification. Turn this off for silent monitoring — captures are still saved.",
                isOn: $settingsManager.notificationsEnabled
            )
        }
    }

    // MARK: - Alarm

    private var alarmCard: some View {
        SettingCard(
            icon: "speaker.wave.3.fill",
            title: "Alarm Siren",
            accent: accent,
            info: "Plays an audible siren on detection, at most once every 30 seconds."
        ) {
            if subscriptionManager.hasAccess(to: .alarmSiren) {
                ToggleRow(
                    title: "Sound an alarm on detection",
                    isOn: $settingsManager.alarmEnabled
                )

                if settingsManager.alarmEnabled {
                    LabelledRow(title: "Sound") {
                        Picker("", selection: $settingsManager.alarmSound) {
                            ForEach(AlarmSound.allCases, id: \.self) { sound in
                                Text(sound.rawValue).tag(sound)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 130)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Volume")
                                .font(.system(size: 13))
                            Spacer()
                            Text("\(Int(settingsManager.alarmVolume * 100))%")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(accent)
                                .monospacedDigit()
                        }
                        Slider(value: $settingsManager.alarmVolume, in: 0.0...1.0, step: 0.05)
                            .tint(WatchdogColor.toggle)
                    }

                    Button(alarmTesting ? "Playing…" : "Test Alarm") {
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
                ProLockRow(feature: .alarmSiren, action: showPaywall)
            }
        }
    }

    // MARK: - Flash

    private var flashCard: some View {
        SettingCard(
            icon: "light.beacon.max.fill",
            title: "Flash Alert",
            accent: accent,
            info: "Flashes the screen so a detection is obvious from across the room, even with the volume muted."
        ) {
            if subscriptionManager.hasAccess(to: .flashAlert) {
                ToggleRow(
                    title: "Flash the screen on detection",
                    subtitle: "A brief red and blue flash. Useful alongside — or instead of — the siren.",
                    isOn: $settingsManager.flashAlertEnabled
                )
            } else {
                ProLockRow(feature: .flashAlert, action: showPaywall)
            }
        }
    }

    // MARK: - Screen dim

    private var screenDimCard: some View {
        SettingCard(
            icon: "moon.fill",
            title: "Screen Dim",
            accent: accent,
            info: "Covers the desktop while monitoring so its contents aren't visible to the room."
        ) {
            if subscriptionManager.hasAccess(to: .screenDim) {
                ToggleRow(
                    title: "Dim the screen while monitoring",
                    isOn: $settingsManager.screenDimEnabled
                )

                if settingsManager.screenDimEnabled {
                    TipCallout(
                        text: "Click Restore Screen to lift the dim; it also lifts on its own after 15 minutes. Watchdog stays in the menu bar and every system shortcut keeps working.",
                        systemImage: "info.circle.fill"
                    )
                }
            } else {
                ProLockRow(feature: .screenDim, action: showPaywall)
            }
        }
    }
}
