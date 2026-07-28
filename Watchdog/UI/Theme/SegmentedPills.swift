import SwiftUI

/// A row of equal-width selectable pills — the control used throughout Preferences for
/// quality, interval and mode choices.
///
/// This exists because `Picker(.segmented)` clips its outer segments when the labels don't
/// fit, silently and at both ends. Here every segment gets the same width, long labels shrink
/// rather than truncate, and the row wraps to a second line instead of overflowing.
struct SegmentedPills<Option: Hashable, Label: View>: View {
    let options: [Option]
    @Binding var selection: Option
    var accent: Color = WatchdogColor.primary
    /// Maximum pills per row before wrapping. Keeps six-item rows readable in a narrow window.
    var maxPerRow: Int = 6
    @ViewBuilder var label: (Option) -> Label

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Lets the selected pill's fill slide between positions rather than blinking out of one and
    /// into another. Scoped per instance so two pickers on screen never adopt each other's fill.
    @Namespace private var selectionNamespace

    private var rows: [[Option]] {
        guard options.count > maxPerRow else { return [options] }
        return stride(from: 0, to: options.count, by: maxPerRow).map {
            Array(options[$0 ..< min($0 + maxPerRow, options.count)])
        }
    }

    var body: some View {
        pillRows
            // One persistent fill that re-targets the selected pill, rather than a rectangle
            // removed from one pill and inserted into another. The insert/remove form does
            // not interpolate — it cuts — which is what this control used to do.
            .background(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: WatchdogMetrics.pillCornerRadius)
                    .fill(accent)
                    .matchedGeometryEffect(id: selection, in: selectionNamespace, isSource: false)
            }
    }

    private var pillRows: some View {
        VStack(spacing: 6) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 6) {
                    ForEach(row, id: \.self) { option in
                        pill(for: option)
                            .background(
                                Color.clear.matchedGeometryEffect(
                                    id: option,
                                    in: selectionNamespace,
                                    isSource: true
                                )
                            )
                    }
                    // Pad a short final row so its pills keep the same width as the rows above.
                    if row.count < maxPerRow && rows.count > 1 {
                        ForEach(0 ..< (maxPerRow - row.count), id: \.self) { _ in
                            Color.clear.frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
    }

    private func pill(for option: Option) -> some View {
        let isSelected = option == selection
        return Button {
            // Animated here rather than on the binding so the caller can't accidentally drop it.
            if reduceMotion {
                selection = option
            } else {
                withAnimation(WatchdogMotion.selection) { selection = option }
            }
        } label: {
            label(option)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .white : .secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity)
                // The travelling accent fill sits behind the whole control, so the selected
                // pill leaves its track clear for the accent to show through. Painting the
                // grey track over it would mute the accent to a wash.
                .background(
                    RoundedRectangle(cornerRadius: WatchdogMetrics.pillCornerRadius)
                        .fill(isSelected ? Color.clear : Color.secondary.opacity(0.10))
                )
                .contentShape(RoundedRectangle(cornerRadius: WatchdogMetrics.pillCornerRadius))
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}

/// Convenience for the common text-only case.
extension SegmentedPills where Label == Text {
    init(
        options: [Option],
        selection: Binding<Option>,
        accent: Color = WatchdogColor.primary,
        maxPerRow: Int = 6,
        title: @escaping (Option) -> String
    ) {
        self.init(
            options: options,
            selection: selection,
            accent: accent,
            maxPerRow: maxPerRow,
            label: { Text(title($0)) }
        )
    }
}

/// A pill that stacks an SF Symbol above its label — used where the icon carries meaning,
/// such as the detection-mode switch in the menu bar popover.
struct IconPillLabel: View {
    let symbol: String
    let title: String

    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: symbol)
                .font(.system(size: 13))
            Text(title)
        }
        .frame(maxWidth: .infinity)
    }
}
