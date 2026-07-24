import SwiftUI
import AppKit

/// Where captures are written, and how long they stay there.
struct StorageTab: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @EnvironmentObject var captureStore: CaptureStore
    @ObservedObject private var appearance = AppearanceSettings.shared

    @State private var confirmDeleteAll = false

    private var accent: Color { appearance.accentColor }

    var body: some View {
        VStack(spacing: 14) {
            saveLocationCard
            cloudCard
            retentionCard
        }
        .alert("Delete all captures?", isPresented: $confirmDeleteAll) {
            Button("Delete All", role: .destructive) { captureStore.deleteAllCaptures() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes every saved image and video clip from \(settingsManager.saveLocation). This cannot be undone.")
        }
    }

    // MARK: - Save location

    private var saveLocationCard: some View {
        SettingCard(
            icon: "folder.fill",
            title: "Save Location",
            accent: accent,
            info: "The folder captures are written to. Choosing a folder grants Watchdog ongoing access to it; that permission is remembered across launches."
        ) {
            HStack(spacing: 8) {
                Image(systemName: "folder")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                Text(settingsManager.saveLocation)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(settingsManager.saveLocation)

                Spacer(minLength: 8)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 7).fill(Color.secondary.opacity(0.08)))

            HStack(spacing: 8) {
                Button("Choose Folder…") { chooseFolder() }
                    .controlSize(.small)

                Button("Reveal in Finder") { revealInFinder() }
                    .controlSize(.small)

                Spacer()

                Button("Reset to Default") { settingsManager.resetSaveLocationToDefault() }
                    .controlSize(.small)
            }
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Select"
        panel.directoryURL = URL(fileURLWithPath: settingsManager.saveLocation)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        // Routed through SettingsManager so a security-scoped bookmark is stored — a bare
        // path grants no access on the next launch under the sandbox.
        settingsManager.setSaveLocation(url)
    }

    private func revealInFinder() {
        NSWorkspace.shared.selectFile(
            nil,
            inFileViewerRootedAtPath: settingsManager.saveLocation
        )
    }

    // MARK: - Cloud backup

    /// A preview of planned cloud sync. Every control is disabled on purpose — see
    /// `CloudDestination` for why this ships inert rather than half-wired.
    private var cloudCard: some View {
        SettingCard(
            icon: "icloud.fill",
            title: "Cloud Backup",
            accent: accent,
            info: "Planned for a future release. Watchdog currently makes no network connections at all, and nothing here is active yet."
        ) {
            VStack(spacing: 8) {
                ForEach(CloudDestination.allCases) { destination in
                    cloudRow(destination)
                }
            }

            TipCallout(
                text: "Cloud sync isn't available yet. Watchdog keeps every capture on this Mac and makes no network connections — these are shown so you can see what's coming.",
                systemImage: "clock.badge.questionmark"
            )
        }
    }

    private func cloudRow(_ destination: CloudDestination) -> some View {
        HStack(spacing: 10) {
            Image(systemName: destination.icon)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 1) {
                Text(destination.displayName)
                    .font(.system(size: 12, weight: .medium))
                Text(destination.blurb)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text("Coming soon")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.secondary.opacity(0.12)))
        }
        .padding(.vertical, 2)
        .opacity(0.6)
    }

    // MARK: - Retention

    private var retentionCard: some View {
        SettingCard(
            icon: "clock.arrow.circlepath",
            title: "Retention",
            accent: accent,
            value: "\(captureStore.captures.count) saved",
            info: "How long captures are kept before Watchdog deletes them, media included."
        ) {
            LabelledRow(
                title: settingsManager.isPaid ? "Kept until you delete them" : "Deleted automatically after 3 days",
                subtitle: settingsManager.isPaid
                    ? "Watchdog Pro keeps every capture until you remove it."
                    : "On the free plan, captures older than 3 days are permanently deleted along with their files."
            ) {
                EmptyView()
            }

            if !settingsManager.isPaid {
                ProLockRow(feature: .unlimitedHistory, action: {})
                    .allowsHitTesting(false)
                    .opacity(0.85)
            }

            Divider()

            Button("Delete All Captures…", role: .destructive) {
                confirmDeleteAll = true
            }
            .controlSize(.small)
            // Bordered buttons don't colour themselves from `role` alone, and this one erases
            // every capture on disk — it needs to look different from "Reveal in Finder".
            .tint(.red)
            .disabled(captureStore.captures.isEmpty)
        }
    }
}
