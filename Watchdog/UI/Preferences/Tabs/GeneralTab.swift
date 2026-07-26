import SwiftUI
import ServiceManagement
import os

/// Startup behaviour, power, privacy links, and subscription status.
struct GeneralTab: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @ObservedObject private var appearance = AppearanceSettings.shared

    @Binding var loginItemError: String?
    @Binding var showRecordingNotice: Bool
    var showPaywall: () -> Void

    private static let log = Logger(subsystem: "com.markstudios.watchdog", category: "settings")

    private var accent: Color { appearance.accentColor }

    var body: some View {
        VStack(spacing: 14) {
            startupCard
            powerCard
            privacyCard
            subscriptionCard
            aboutCard
        }
    }

    // MARK: - Startup

    private var startupCard: some View {
        SettingCard(
            icon: "power",
            title: "Startup",
            accent: accent,
            info: "Registers Watchdog as a login item. The app must be in your Applications folder and properly signed for this to succeed."
        ) {
            ToggleRow(
                title: "Launch at login",
                subtitle: "Starts Watchdog when you log in. Monitoring still has to be switched on by you — it never starts by itself.",
                isOn: Binding(
                    get: { settingsManager.launchAtLogin },
                    set: { setLaunchAtLogin($0) }
                )
            )
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        settingsManager.launchAtLogin = enabled
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            Self.log.error("Launch at login failed: \(error.localizedDescription, privacy: .public)")
            settingsManager.launchAtLogin = !enabled
            loginItemError = "Failed to \(enabled ? "enable" : "disable") launch at login. The app must be in your Applications folder and properly signed."
        }
    }

    // MARK: - Power

    private var powerCard: some View {
        SettingCard(
            icon: "bolt.fill",
            title: "Power",
            accent: accent,
            info: "Keeps the Mac awake so monitoring isn't interrupted. Both options increase power draw noticeably on battery."
        ) {
            ToggleRow(
                title: "Prevent system sleep",
                subtitle: "Keeps your Mac awake while Watchdog is running so monitoring is never interrupted.",
                isOn: $settingsManager.preventSleep
            )

            ToggleRow(
                title: "Prevent screen lock",
                subtitle: "Keeps the display on and prevents auto-lock. Useful if you need the camera to stay active.",
                isOn: $settingsManager.preventScreenLock
            )
        }
    }

    // MARK: - Privacy

    /// Guideline 5.1.1 expects the privacy policy to be reachable from inside the app, and
    /// users need a direct way to re-read what Watchdog records of them and others.
    private var privacyCard: some View {
        SettingCard(
            icon: "hand.raised.fill",
            title: "Privacy & Legal",
            accent: accent,
            info: "Watchdog stores captures on this Mac only. It has no account system, no analytics, and makes no network connections."
        ) {
            Button("Review What Watchdog Records…") {
                showRecordingNotice = true
            }
            .controlSize(.small)

            HStack(spacing: 6) {
                Link("Privacy Policy", destination: LegalLinks.privacyPolicy)
                Text("·").foregroundColor(.secondary)
                Link("Terms of Use", destination: LegalLinks.termsOfUse)
                Text("·").foregroundColor(.secondary)
                Link("Support", destination: LegalLinks.support)
                Spacer()
            }
            .font(.system(size: 11))
        }
    }

    // MARK: - Subscription

    private var subscriptionCard: some View {
        SettingCard(
            icon: "star.fill",
            title: "Subscription",
            accent: accent,
            value: subscriptionManager.status.displayName
        ) {
            switch subscriptionManager.status {
            case .subscribed(_, let expiresDate):
                statusRow(
                    icon: "checkmark.seal.fill",
                    tint: WatchdogColor.live,
                    title: "Watchdog Pro",
                    subtitle: "Renews \(expiresDate.formatted(date: .abbreviated, time: .omitted))"
                )

                Link("Manage Subscription", destination: LegalLinks.manageSubscriptions)
                    .font(.system(size: 11))

            case .trial(let daysRemaining):
                statusRow(
                    icon: "clock.fill",
                    tint: WatchdogColor.warn,
                    title: "Free Trial",
                    subtitle: "\(daysRemaining) day\(daysRemaining == 1 ? "" : "s") remaining — all features unlocked"
                )

                Button("See Pro Plans") { showPaywall() }
                    .controlSize(.small)

            case .free, .expired:
                statusRow(
                    icon: subscriptionManager.status == .expired ? "exclamationmark.triangle.fill" : "hourglass",
                    tint: WatchdogColor.warn,
                    title: subscriptionManager.status == .expired ? "Trial Expired" : "Free Plan",
                    subtitle: "Captures are kept for 3 days"
                )

                Button(action: showPaywall) {
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill")
                        Text("Upgrade to Pro")
                    }
                    .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .tint(accent)
            }
        }
    }

    private func statusRow(icon: String, tint: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(tint)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }

    // MARK: - About

    private var aboutCard: some View {
        SettingCard(
            icon: "info.circle.fill",
            title: "About",
            accent: accent,
            value: "v\(Self.appVersion)"
        ) {
            Text("Watchdog turns your Mac's camera into a local security monitor. Captures never leave this device.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            TipCallout(
                text: "The camera indicator light is controlled by hardware on Apple silicon. It turns on whenever the camera is active and Watchdog cannot switch it off.",
                systemImage: "lightbulb.fill"
            )
        }
    }

    private static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
}
