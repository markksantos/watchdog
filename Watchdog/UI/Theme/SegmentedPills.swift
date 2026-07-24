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

    private var rows: [[Option]] {
        guard options.count > maxPerRow else { return [options] }
        return stride(from: 0, to: options.count, by: maxPerRow).map {
            Array(options[$0 ..< min($0 + maxPerRow, options.count)])
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 6) {
                    ForEach(row, id: \.self) { option in
                        pill(for: option)
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
            selection = option
        } label: {
            label(option)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .white : .secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: WatchdogMetrics.pillCornerRadius)
                        .fill(isSelected ? accent : Color.secondary.opacity(0.10))
                )
                .contentShape(RoundedRectangle(cornerRadius: WatchdogMetrics.pillCornerRadius))
        }
        .buttonStyle(.plain)
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
