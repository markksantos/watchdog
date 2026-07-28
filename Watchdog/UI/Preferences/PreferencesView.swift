import SwiftUI

/// The tabs across the top of Preferences.
enum PreferencesTab: String, CaseIterable, Identifiable {
    case camera, recording, storage, alerts, appearance, general

    var id: String { rawValue }

    var title: String {
        switch self {
        case .camera: return "Camera"
        case .recording: return "Recording"
        case .storage: return "Storage"
        case .alerts: return "Alerts"
        case .appearance: return "Appearance"
        case .general: return "General"
        }
    }

    var icon: String {
        switch self {
        case .camera: return "camera.fill"
        case .recording: return "video.fill"
        case .storage: return "folder.fill"
        case .alerts: return "bell.fill"
        case .appearance: return "paintbrush.fill"
        case .general: return "gearshape.fill"
        }
    }
}

/// Preferences, grouped into tabs.
///
/// Replaces a single 780pt-tall scrolling form that stacked seven sections with no way to
/// navigate between them. This view owns only the tab bar and the shared sheets; each tab's
/// content lives in its own file so a change to one group can't disturb another.
struct PreferencesView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @EnvironmentObject var captureStore: CaptureStore
    @ObservedObject private var appearance = AppearanceSettings.shared

    @State private var selectedTab: PreferencesTab = .camera
    @State private var showPaywall = false
    @State private var showRecordingNotice = false
    @State private var loginItemError: String?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Carries the selected tab's highlight between buttons instead of redrawing it in place.
    @Namespace private var tabNamespace

    private var accent: Color { appearance.accentColor }

    var body: some View {
        VStack(spacing: 0) {
            tabBar

            Divider()

            ScrollView {
                content
                    .padding(16)
                    // Keyed on the tab so switching swaps the whole pane and the transition
                    // has two distinct views to cross between.
                    .id(selectedTab)
                    .transition(WatchdogTransition.pane(reduceMotion: reduceMotion))
            }
            .background(WatchdogColor.canvas)
        }
        // Resizable rather than pinned: the Camera tab is short while Recording and General
        // are tall, so a single fixed height either clips the long tabs or leaves the short
        // ones mostly empty.
        .frame(
            minWidth: WatchdogMetrics.preferencesWidth,
            maxWidth: .infinity,
            minHeight: 460,
            maxHeight: .infinity
        )
        // No window-wide `.tint`: on macOS it recolours every bordered button's label, so a
        // red accent made "Reveal in Finder" look as destructive as "Delete All Captures".
        // The accent is applied deliberately — pills, sliders, primary buttons — instead.
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .environmentObject(subscriptionManager)
        }
        .sheet(isPresented: $showRecordingNotice) {
            RecordingNoticeView(isReview: true)
                .environmentObject(settingsManager)
        }
        .alert("Launch at Login", isPresented: .init(
            get: { loginItemError != nil },
            set: { if !$0 { loginItemError = nil } }
        )) {
            Button("OK") { loginItemError = nil }
        } message: {
            Text(loginItemError ?? "")
        }
    }

    // MARK: - Tab bar

    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(PreferencesTab.allCases) { tab in
                tabButton(tab)
                    // An invisible per-tab anchor. The pill below follows whichever of these
                    // is currently selected.
                    .background(
                        Color.clear.matchedGeometryEffect(id: tab, in: tabNamespace, isSource: true)
                    )
            }
        }
        // The highlight is one persistent view that re-targets, rather than a rectangle that
        // is removed from one button and inserted into another. SwiftUI only interpolates a
        // frame it can see continuously; the insert/remove form just cuts, which is exactly
        // what it did here before — verified by frame capture, not by eye.
        .background(alignment: .leading) {
            RoundedRectangle(cornerRadius: WatchdogMetrics.pillCornerRadius)
                .fill(accent)
                .matchedGeometryEffect(
                    id: selectedTab,
                    in: tabNamespace,
                    isSource: false
                )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(.bar)
    }

    private func tabButton(_ tab: PreferencesTab) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            if reduceMotion {
                selectedTab = tab
            } else {
                withAnimation(WatchdogMotion.selection) { selectedTab = tab }
            }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: tab.icon)
                    .font(.system(size: 14))
                    // A hair larger while selected, so the active tab reads even in a
                    // screenshot where the accent fill has been desaturated.
                    .scaleEffect(isSelected && !reduceMotion ? 1.08 : 1)
                Text(tab.title)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundColor(isSelected ? .white : .secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .contentShape(RoundedRectangle(cornerRadius: WatchdogMetrics.pillCornerRadius))
        }
        .buttonStyle(PressableButtonStyle(scale: 0.95))
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch selectedTab {
        case .camera:
            CameraTab()

        case .recording:
            RecordingTab(showPaywall: { showPaywall = true })

        case .storage:
            StorageTab()

        case .alerts:
            AlertsTab(showPaywall: { showPaywall = true })

        case .appearance:
            AppearanceTab()

        case .general:
            GeneralTab(
                loginItemError: $loginItemError,
                showRecordingNotice: $showRecordingNotice,
                showPaywall: { showPaywall = true }
            )
        }
    }
}
