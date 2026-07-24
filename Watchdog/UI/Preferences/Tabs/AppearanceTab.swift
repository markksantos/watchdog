import SwiftUI

/// How Watchdog looks: theme, accent, menu bar glyph, gallery density.
struct AppearanceTab: View {
    @ObservedObject private var appearance = AppearanceSettings.shared

    private var accent: Color { appearance.accentColor }

    var body: some View {
        VStack(spacing: 14) {
            themeCard
            accentCard
            menuBarCard
            galleryCard
            resetCard
        }
    }

    // MARK: - Theme

    private var themeCard: some View {
        SettingCard(
            icon: "circle.lefthalf.filled",
            title: "Theme",
            accent: accent,
            value: appearance.theme.displayName,
            info: "Auto follows your macOS appearance setting, including the automatic light-to-dark switch at sunset."
        ) {
            SegmentedPills(
                options: AppTheme.allCases,
                selection: $appearance.theme,
                accent: accent,
                maxPerRow: 3
            ) { theme in
                IconPillLabel(symbol: theme.icon, title: theme.displayName)
            }
        }
    }

    // MARK: - Accent

    private var accentCard: some View {
        SettingCard(
            icon: "paintpalette.fill",
            title: "Accent Color",
            accent: accent,
            value: appearance.accent.displayName,
            info: "Tints selected controls and highlights throughout the app. Status colours — green for live, amber for warnings — stay fixed so they keep their meaning."
        ) {
            HStack(spacing: 10) {
                ForEach(AccentChoice.allCases) { choice in
                    swatch(choice)
                }
                Spacer()
            }
        }
    }

    private func swatch(_ choice: AccentChoice) -> some View {
        let isSelected = appearance.accent == choice
        return Button {
            appearance.accent = choice
        } label: {
            ZStack {
                Circle()
                    .fill(choice.color)
                    .frame(width: 26, height: 26)

                if choice == .system {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }

                if isSelected {
                    Circle()
                        .strokeBorder(Color.primary.opacity(0.65), lineWidth: 2)
                        .frame(width: 33, height: 33)
                }
            }
            .frame(width: 36, height: 36)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(choice.displayName)
        .accessibilityLabel(choice.displayName)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }

    // MARK: - Menu bar

    private var menuBarCard: some View {
        SettingCard(
            icon: "menubar.rectangle",
            title: "Menu Bar",
            accent: accent,
            info: "The menu bar item is always visible while Watchdog runs — only its glyph changes. Watchdog cannot hide itself, and does not try to."
        ) {
            SegmentedPills(
                options: MenuBarIcon.allCases,
                selection: $appearance.menuBarIcon,
                accent: accent,
                maxPerRow: 4
            ) { icon in
                IconPillLabel(symbol: icon.activeSymbol, title: icon.displayName)
            }

            ToggleRow(
                title: "Show today's capture count",
                subtitle: "Displays the number of captures taken today next to the icon.",
                isOn: $appearance.showMenuBarCount
            )
        }
    }

    // MARK: - Gallery

    private var galleryCard: some View {
        SettingCard(
            icon: "square.grid.2x2.fill",
            title: "Gallery",
            accent: accent,
            value: "\(Int(appearance.galleryThumbnailSize)) pt",
            info: "Thumbnail size in the captures grid. Larger thumbnails mean fewer per row."
        ) {
            Slider(value: $appearance.galleryThumbnailSize, in: 120...280, step: 20)
                .tint(WatchdogColor.toggle)

            HStack {
                Text("More per row")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Spacer()
                Text("Larger previews")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            ToggleRow(
                title: "Show tips",
                subtitle: "The amber hint boxes throughout Preferences. Turn off once you know your way around.",
                isOn: $appearance.showTips
            )
        }
    }

    // MARK: - Reset

    private var resetCard: some View {
        HStack {
            Spacer()
            Button("Reset Appearance to Defaults") {
                appearance.resetToDefaults()
            }
            .controlSize(.small)
        }
    }
}
