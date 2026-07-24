import SwiftUI

/// Image quality, video clips, and when monitoring is allowed to run.
struct RecordingTab: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @ObservedObject private var captureSettings = CaptureSettings.shared
    @ObservedObject private var appearance = AppearanceSettings.shared

    var showPaywall: () -> Void

    private var accent: Color { appearance.accentColor }

    var body: some View {
        VStack(spacing: 14) {
            resolutionCard
            compressionCard
            videoCard
            scheduleCard
        }
    }

    // MARK: - Resolution

    private var resolutionCard: some View {
        SettingCard(
            icon: "arrow.up.left.and.arrow.down.right",
            title: "Photo Resolution",
            accent: accent,
            value: resolutionValueLabel,
            info: "The pixel size captures are saved at. Watchdog only ever scales down — asking for more pixels than your camera produces would invent detail that was never there, so the frame is left at its native size instead."
        ) {
            SegmentedPills(
                options: PhotoResolution.presets + [.custom],
                selection: $captureSettings.resolution,
                accent: accent,
                maxPerRow: 4
            ) { resolution in
                Text(resolution.shortLabel)
            }

            if captureSettings.resolution == .custom {
                customDimensionFields
            }
        }
    }

    private var resolutionValueLabel: String {
        switch captureSettings.resolution {
        case .native: return "Native"
        case .custom: return "\(captureSettings.customWidth)×\(captureSettings.customHeight)"
        default: return captureSettings.resolution.label
        }
    }

    private var customDimensionFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                dimensionField(
                    value: Binding(
                        get: { captureSettings.customWidth },
                        set: { captureSettings.customWidth = $0 }
                    ),
                    label: "Width"
                )

                Text("×")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)

                dimensionField(
                    value: Binding(
                        get: { captureSettings.customHeight },
                        set: { captureSettings.customHeight = $0 }
                    ),
                    label: "Height"
                )

                Text("px")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                Spacer()
            }

            Text("Between \(CaptureSettings.dimensionRange.lowerBound) and \(CaptureSettings.dimensionRange.upperBound) pixels. Aspect ratio is preserved — this is the box your capture is fitted inside, not a forced stretch.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func dimensionField(value: Binding<Int>, label: String) -> some View {
        TextField(label, value: value, format: .number)
            .textFieldStyle(.roundedBorder)
            .frame(width: 80)
            .multilineTextAlignment(.trailing)
            .accessibilityLabel(label)
    }

    // MARK: - Compression

    private var compressionCard: some View {
        SettingCard(
            icon: "slider.horizontal.below.rectangle",
            title: "Compression",
            accent: accent,
            value: "\(Int(captureSettings.compression * 100))%",
            info: "JPEG quality. Independent of resolution: resolution decides how much detail exists, compression decides how cleanly it is stored."
        ) {
            Slider(value: $captureSettings.compression, in: 0.1...1.0, step: 0.05)
                .tint(WatchdogColor.toggle)

            HStack {
                Text("Smaller files")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Spacer()
                Text("Best quality")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            if appearance.showTips {
                TipCallout(text: "Around 80–90% is the sweet spot. Below 50% you'll see blocky artifacts on faces, which defeats the point of a security capture.")
            }
        }
    }

    // MARK: - Video

    private var videoCard: some View {
        SettingCard(
            icon: "video.fill",
            title: "Video Recording",
            accent: accent,
            info: "Records a short clip alongside the still image each time a detection fires."
        ) {
            if subscriptionManager.hasAccess(to: .videoRecording) {
                ToggleRow(
                    title: "Record a clip on each detection",
                    subtitle: "Saves a 5-second H.264 clip next to the capture. Uses noticeably more disk than stills alone.",
                    isOn: $settingsManager.videoRecordingEnabled
                )
            } else {
                ProLockRow(feature: .videoRecording, action: showPaywall)
            }
        }
    }

    // MARK: - Schedule

    private var scheduleCard: some View {
        SettingCard(
            icon: "clock.badge.checkmark",
            title: "Detection Schedule",
            accent: accent,
            value: settingsManager.scheduleConfig.isEnabled
                ? settingsManager.scheduleConfig.formattedTimeRange
                : nil,
            info: "Limits monitoring to a time window and set of weekdays. Outside the window, frames are ignored and nothing is written."
        ) {
            if subscriptionManager.hasAccess(to: .detectionScheduling) {
                ToggleRow(
                    title: "Only monitor during set hours",
                    isOn: $settingsManager.scheduleConfig.isEnabled
                )

                if settingsManager.scheduleConfig.isEnabled {
                    HStack(spacing: 12) {
                        hourPicker(title: "From", selection: $settingsManager.scheduleConfig.startHour)
                        hourPicker(title: "To", selection: $settingsManager.scheduleConfig.endHour)
                        Spacer()
                    }

                    weekdayPicker
                }
            } else {
                ProLockRow(feature: .detectionScheduling, action: showPaywall)
            }
        }
    }

    private func hourPicker(title: String, selection: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Picker("", selection: selection) {
                ForEach(0..<24, id: \.self) { hour in
                    Text(Self.formatHour(hour)).tag(hour)
                }
            }
            .labelsHidden()
            .frame(width: 92)
        }
    }

    private var weekdayPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Active days")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            HStack(spacing: 5) {
                ForEach(Weekday.allCases) { day in
                    weekdayButton(day)
                }
                Spacer()
            }
        }
    }

    private func weekdayButton(_ day: Weekday) -> some View {
        let isActive = settingsManager.scheduleConfig.activeWeekdays.contains(day)
        // Emptying the set entirely would silently disable monitoring on every day while the
        // schedule still reads as enabled, so the last active day cannot be switched off.
        let isLastActive = isActive && settingsManager.scheduleConfig.activeWeekdays.count == 1

        return Button {
            if isActive {
                settingsManager.scheduleConfig.activeWeekdays.remove(day)
            } else {
                settingsManager.scheduleConfig.activeWeekdays.insert(day)
            }
        } label: {
            Text(day.shortName)
                .font(.system(size: 11, weight: isActive ? .semibold : .regular))
                .foregroundColor(isActive ? .white : .secondary)
                .frame(width: 34, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isActive ? accent : Color.secondary.opacity(0.12))
                )
        }
        .buttonStyle(.plain)
        .disabled(isLastActive)
        .help(isLastActive ? "At least one day must stay active." : day.shortName)
    }

    private static func formatHour(_ hour: Int) -> String {
        let period = hour >= 12 ? "PM" : "AM"
        let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        return "\(displayHour) \(period)"
    }
}
