import SwiftUI

/// Watchdog's motion vocabulary.
///
/// Every animation in the app comes from here rather than from an inline `.easeInOut(duration:)`,
/// for the same reason every colour comes from `WatchdogColor`: so the feel can be tuned in one
/// place, and so nothing ships at a duration someone picked at 2am.
///
/// The durations are deliberately short. This is a menu bar utility that people open to flip one
/// switch and close again — motion here is meant to explain what changed, not to be noticed.
enum WatchdogMotion {
    /// Colour, opacity and other non-moving state flips. Fast enough to feel immediate.
    static let quick = Animation.easeOut(duration: 0.16)
    /// The default for a state change that alters layout slightly.
    static let standard = Animation.easeInOut(duration: 0.22)
    /// Content appearing or disappearing, where a little more time reads as deliberate.
    static let gentle = Animation.easeInOut(duration: 0.32)
    /// Selection indicators sliding between positions. Slight overshoot, no visible bounce.
    static let selection = Animation.spring(response: 0.32, dampingFraction: 0.78)
    /// Press feedback — must be near-instant or the control feels laggy rather than responsive.
    static let press = Animation.easeOut(duration: 0.12)
    /// The "something is live" heartbeat. Continuous, so it is suppressed under Reduce Motion.
    static let pulse = Animation.easeInOut(duration: 1.2).repeatForever(autoreverses: true)
}

// MARK: - Reduce Motion

/// Applies an animation that is safe under Reduce Motion.
///
/// Fades and colour changes are what Apple recommends motion be *replaced* with, so they keep
/// animating either way.
private struct FadeAnimation<V: Equatable>: ViewModifier {
    let animation: Animation
    let value: V

    func body(content: Content) -> some View {
        content.animation(animation, value: value)
    }
}

/// Applies an animation that moves, scales or rotates something.
///
/// Under Reduce Motion the animation is dropped and the change applies instantly. That is the
/// honest fallback: easing a transform more slowly is still the motion the user asked not to see.
private struct TransformAnimation<V: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let animation: Animation
    let value: V

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? nil : animation, value: value)
    }
}

extension View {
    /// Animate a colour/opacity change. Runs regardless of Reduce Motion.
    func wdFade<V: Equatable>(_ animation: Animation = WatchdogMotion.quick, value: V) -> some View {
        modifier(FadeAnimation(animation: animation, value: value))
    }

    /// Animate a change that moves or scales. Suppressed under Reduce Motion.
    func wdMotion<V: Equatable>(_ animation: Animation = WatchdogMotion.standard, value: V) -> some View {
        modifier(TransformAnimation(animation: animation, value: value))
    }
}

/// Transitions that degrade to a plain fade under Reduce Motion.
enum WatchdogTransition {
    /// Content that grows into place from the top, e.g. a button revealed by a toggle.
    static func reveal(reduceMotion: Bool) -> AnyTransition {
        reduceMotion
            ? .opacity
            : .asymmetric(
                insertion: .move(edge: .top).combined(with: .opacity),
                removal: .opacity
            )
    }

    /// A badge or chip appearing in place.
    static func pop(reduceMotion: Bool) -> AnyTransition {
        reduceMotion ? .opacity : .scale(scale: 0.85).combined(with: .opacity)
    }

    /// Switching between two full-pane contents.
    static func pane(reduceMotion: Bool) -> AnyTransition {
        reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.99))
    }
}

// MARK: - Press feedback

/// Scales a control down very slightly while the mouse is held on it.
///
/// `.plain` button style on macOS gives no feedback at all beyond the cursor, which on a custom
/// pill leaves the user unsure whether the click registered. 3% is enough to feel, small enough
/// not to shift the layout around it.
struct PressableButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var scale: CGFloat = 0.97
    /// Dim slightly as well, so the feedback survives Reduce Motion.
    var pressedOpacity: Double = 0.82

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion || !configuration.isPressed ? 1 : scale)
            .opacity(configuration.isPressed ? pressedOpacity : 1)
            .animation(WatchdogMotion.press, value: configuration.isPressed)
    }
}

// MARK: - Hover

/// Raises a view a little while the pointer is over it.
///
/// Used on grid cells, where the pointer is the only thing indicating which item a click will
/// open — the cells have no other selected state.
struct HoverLift: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var scale: CGFloat = 1.02
    var lift: CGFloat = 2
    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovering && !reduceMotion ? scale : 1)
            .offset(y: isHovering && !reduceMotion ? -lift : 0)
            .shadow(
                color: .black.opacity(isHovering ? 0.22 : 0.10),
                radius: isHovering ? 8 : 2,
                y: isHovering ? 4 : 1
            )
            .animation(WatchdogMotion.standard, value: isHovering)
            .onHover { isHovering = $0 }
    }
}

extension View {
    func hoverLift(scale: CGFloat = 1.02, lift: CGFloat = 2) -> some View {
        modifier(HoverLift(scale: scale, lift: lift))
    }
}

// MARK: - Live indicator

/// The small dot that says "the camera is on".
///
/// It breathes rather than blinks: a hard on/off flash in the corner of the eye reads as an error
/// indicator, which this is not. Under Reduce Motion it simply sits there, lit — the colour alone
/// still carries the meaning, so nothing is lost.
struct PulsingDot: View {
    var color: Color
    var size: CGFloat = 7
    var isAnimating: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPulsing = false

    private var shouldPulse: Bool { isAnimating && !reduceMotion }

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .stroke(color, lineWidth: 1.5)
                    .scaleEffect(isPulsing ? 2.1 : 1)
                    .opacity(isPulsing ? 0 : 0.65)
            )
            .onAppear {
                guard shouldPulse else { return }
                withAnimation(WatchdogMotion.pulse) { isPulsing = true }
            }
            .onChange(of: shouldPulse) { pulse in
                if pulse {
                    withAnimation(WatchdogMotion.pulse) { isPulsing = true }
                } else {
                    withAnimation(WatchdogMotion.quick) { isPulsing = false }
                }
            }
    }
}

/// A symbol that swells and settles on a long cycle.
///
/// Reserved for empty states, where the only thing on screen is one glyph and a line of text.
/// Suppressed under Reduce Motion, which leaves a perfectly good static icon.
struct BreathingIcon: View {
    let systemName: String
    var size: CGFloat = 48

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isBreathing = false

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size))
            .scaleEffect(isBreathing ? 1.06 : 1)
            .opacity(isBreathing ? 1 : 0.82)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                    isBreathing = true
                }
            }
    }
}

/// Fades a row in with a delay proportional to its position in a list.
///
/// The step is deliberately small. A long stagger on a list someone is trying to read is a
/// delay dressed up as polish.
struct StaggeredEntrance: ViewModifier {
    let index: Int
    var step: Double = 0.03
    var maxDelay: Double = 0.3

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasAppeared = false

    func body(content: Content) -> some View {
        content
            .opacity(hasAppeared || reduceMotion ? 1 : 0)
            .offset(y: hasAppeared || reduceMotion ? 0 : 6)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(WatchdogMotion.gentle.delay(min(Double(index) * step, maxDelay))) {
                    hasAppeared = true
                }
            }
    }
}

/// Fades and lifts an empty/placeholder pane into place the first time it is shown.
struct EmptyStateEntrance: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasAppeared = false

    func body(content: Content) -> some View {
        content
            .opacity(hasAppeared || reduceMotion ? 1 : 0)
            .scaleEffect(hasAppeared || reduceMotion ? 1 : 0.96)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(WatchdogMotion.gentle) { hasAppeared = true }
            }
    }
}

// MARK: - Numbers

/// A number that rolls rather than cutting when it changes.
///
/// `contentTransition(.numericText())` is macOS 14+, so on 13 this is a plain label — the digits
/// still update, they just swap. Nothing depends on the transition being present.
struct AnimatedNumber: View {
    let value: Int
    var format: (Int) -> String = { "\($0)" }

    var body: some View {
        if #available(macOS 14.0, *) {
            Text(format(value))
                .monospacedDigit()
                .contentTransition(.numericText())
                .wdFade(WatchdogMotion.standard, value: value)
        } else {
            Text(format(value))
                .monospacedDigit()
        }
    }
}

// MARK: - Symbols

/// An SF Symbol that crossfades when the symbol name changes, instead of hard-cutting.
struct AnimatedSymbol: View {
    let systemName: String
    var font: Font = .system(size: 13)

    var body: some View {
        Image(systemName: systemName)
            .font(font)
            // The id forces a real view swap, which is what gives the transition something to do.
            .id(systemName)
            .transition(.opacity.combined(with: .scale(scale: 0.82)))
    }
}
