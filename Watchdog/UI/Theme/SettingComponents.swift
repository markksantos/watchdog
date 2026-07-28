import SwiftUI

// MARK: - Info button

/// The trailing ⓘ on a setting header. Explains *why* a setting matters, on demand, so the
/// default view stays uncluttered.
struct InfoButton: View {
    let text: String
    @State private var isShowing = false

    var body: some View {
        Button {
            isShowing.toggle()
        } label: {
            Image(systemName: isShowing ? "info.circle.fill" : "info.circle")
                .font(.system(size: 12))
                .foregroundColor(isShowing ? WatchdogColor.primary : .secondary)
                .wdFade(value: isShowing)
        }
        .buttonStyle(PressableButtonStyle(scale: 0.88))
        .help(text)
        .accessibilityLabel("More information")
        .popover(isPresented: $isShowing, arrowEdge: .bottom) {
            Text(text)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(12)
                .frame(width: 260)
        }
    }
}

// MARK: - Section header

/// `▮ Video Quality                    ⓘ` — the icon + bold title + optional value + info row
/// that heads every setting group.
struct SettingHeader: View {
    let icon: String
    let title: String
    var accent: Color = WatchdogColor.primary
    /// Small emphasised value shown before the info button, e.g. the sensitivity number.
    var value: String?
    var info: String?

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(accent)
                .frame(width: 20)

            Text(title)
                .font(.system(size: 14, weight: .semibold))

            Spacer(minLength: 8)

            if let value {
                Text(value)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(accent)
                    .monospacedDigit()
                    // The header value tracks a slider, so it changes constantly while
                    // dragging. A crossfade keyed on the string keeps that readable.
                    .id(value)
                    .transition(.opacity)
                    .wdFade(WatchdogMotion.press, value: value)
            }

            if let info {
                InfoButton(text: info)
            }
        }
    }
}

// MARK: - Card

/// A settings group: header, then content, on a rounded surface.
struct SettingCard<Content: View>: View {
    let icon: String
    let title: String
    var accent: Color = WatchdogColor.primary
    var value: String?
    var info: String?
    @ViewBuilder var content: Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasAppeared = false
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingHeader(icon: icon, title: title, accent: accent, value: value, info: info)
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: WatchdogMetrics.cardCornerRadius)
                .fill(WatchdogColor.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: WatchdogMetrics.cardCornerRadius)
                // The border warms toward the accent under the pointer. Enough to tell you
                // which card you're about to interact with, not enough to look selected.
                .strokeBorder(
                    isHovering ? accent.opacity(0.35) : WatchdogColor.cardBorder,
                    lineWidth: 1
                )
        )
        .wdFade(WatchdogMotion.standard, value: isHovering)
        .onHover { isHovering = $0 }
        // Cards ease in when their tab is first shown. Without this the whole pane arrives
        // as one hard cut, which makes a tab switch feel like a window reload.
        .opacity(hasAppeared || reduceMotion ? 1 : 0)
        .offset(y: hasAppeared || reduceMotion ? 0 : 8)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(WatchdogMotion.gentle) { hasAppeared = true }
        }
    }
}

// MARK: - Tip callout

/// The amber `💡 Example: Small movements` box. Suppressible from Appearance for users who
/// have learned the app and want the density back.
struct TipCallout: View {
    let text: String
    var systemImage: String = "lightbulb.fill"

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 11))
                .foregroundColor(WatchdogColor.tip)
            Text(text)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                // The text changes as the slider moves through its ranges; crossfading it
                // stops the callout flickering between wordings mid-drag.
                .id(text)
                .transition(.opacity)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(WatchdogColor.tip.opacity(0.12))
        )
        .wdFade(WatchdogMotion.standard, value: text)
        .transition(WatchdogTransition.reveal(reduceMotion: reduceMotion))
    }
}

// MARK: - Pro lock

/// Stands in for a Pro-only control, and opens the paywall when tapped.
struct ProLockRow: View {
    let feature: ProFeature
    var action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: feature.icon)
                    .font(.system(size: 13))
                    .foregroundColor(WatchdogColor.pro)
                    .frame(width: 20)
                    // The icon leans in under the pointer — a small hint that the row is a
                    // button rather than a disabled control, which is easy to assume here.
                    .scaleEffect(isHovering && !reduceMotion ? 1.12 : 1)

                VStack(alignment: .leading, spacing: 2) {
                    Text(feature.rawValue)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                    Text(feature.description)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 8)

                Text("PRO")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(WatchdogColor.pro))
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(WatchdogColor.pro.opacity(isHovering ? 0.14 : 0.07))
            )
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(PressableButtonStyle(scale: 0.985))
        .wdFade(WatchdogMotion.standard, value: isHovering)
        .onHover { isHovering = $0 }
    }
}

// MARK: - Labelled row

/// A left-aligned label with trailing content, for rows that aren't pill pickers.
struct LabelledRow<Trailing: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13))
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            trailing
        }
    }
}

// MARK: - Toggle row

/// A switch with an explanatory subtitle, tinted blue per the palette.
struct ToggleRow: View {
    let title: String
    var subtitle: String?
    @Binding var isOn: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Toggle(isOn: $isOn) {
                Text(title)
                    .font(.system(size: 13))
            }
            .toggleStyle(.switch)
            .tint(WatchdogColor.toggle)

            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
