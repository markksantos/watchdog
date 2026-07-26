import SwiftUI

/// Shown once, before the camera is ever opened, and re-openable from Preferences.
///
/// Watchdog photographs whoever walks up to the Mac — people who are not the purchaser and
/// who cannot consent themselves. This screen makes the user acknowledge what is recorded,
/// where it goes, and that notifying and lawfully recording other people is their
/// responsibility. `DetectionEngine.startMonitoring()` refuses to run until it is accepted.
struct RecordingNoticeView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @Environment(\.dismiss) private var dismiss

    /// When true this is being read back from Preferences rather than gating first use.
    var isReview: Bool = false

    @State private var acknowledged = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header

            VStack(alignment: .leading, spacing: 14) {
                point(
                    icon: "camera.fill",
                    title: "Watchdog records people",
                    body: "When monitoring is on, Watchdog saves a still image — and, on Pro, a 5-second clip — of whoever is in front of this Mac. That may include people who don't know the camera is running."
                )
                point(
                    icon: "internaldrive.fill",
                    title: "Captures stay on this Mac",
                    body: "Everything is written to your capture folder on this device. Watchdog has no account system, no analytics, and makes no network connections. Nothing is ever sent to the developer."
                )
                point(
                    icon: "clock.arrow.circlepath",
                    title: "Free captures are deleted after 3 days",
                    body: "On the free tier, captures older than 3 days are permanently deleted, media and all. Watchdog Pro keeps them until you delete them yourself."
                )
                point(
                    icon: "checkmark.shield.fill",
                    title: "Lawful use is your responsibility",
                    body: "Recording other people is regulated in many places, and rules differ by country, state, and setting — workplaces and shared homes especially. You are responsible for complying with the law where you are, and for telling people who may be recorded."
                )
            }

            Link("Read the Privacy Policy", destination: LegalLinks.privacyPolicy)
                .font(.system(size: 12))

            Divider()

            if isReview {
                HStack {
                    Spacer()
                    Button("Done") { dismiss() }
                        .keyboardShortcut(.defaultAction)
                }
            } else {
                Toggle(isOn: $acknowledged) {
                    Text("I understand what Watchdog records, and I'm responsible for using it lawfully.")
                        .font(.system(size: 12))
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack {
                    Button("Not Now") { dismiss() }
                    Spacer()
                    Button("Continue") {
                        settingsManager.hasAcceptedRecordingNotice = true
                        dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!acknowledged)
                }
            }
        }
        .padding(28)
        .frame(width: 520)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "eye.trianglebadge.exclamationmark.fill")
                .font(.system(size: 32))
                .foregroundStyle(.tint)
            Text("Before you start monitoring")
                .font(.system(size: 20, weight: .semibold))
            Text("macOS shows a green indicator next to the menu bar whenever the camera is active. Watchdog cannot hide it, and does not try to.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func point(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.accentColor)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(body)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
