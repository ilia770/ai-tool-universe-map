import SwiftUI

/// Bouncy scale-down on press + soft haptic. Used as the default
/// button style for every tappable surface in My AI Map. Replicates
/// the "everything feels alive" quality of premium iOS apps without
/// scattering `.scaleEffect` + `.onTapGesture` boilerplate.
///
/// Usage:
///
/// ```swift
/// Button("Open Coding world") { ... }
///   .buttonStyle(PressableButtonStyle())
/// ```
struct PressableButtonStyle: ButtonStyle {
    /// Scale to apply on press. 0.96 is the iOS default feel.
    var pressedScale: CGFloat = 0.96

    /// Haptic to fire on press-down. Set to `nil` to skip.
    var haptic: BrandHaptic? = .light

    /// Subtle background dim while pressed.
    var pressedOpacity: Double = 0.86

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(scale(for: configuration))
            .opacity(opacity(for: configuration))
            .brandAnimation(BrandMotion.nudge, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                guard isPressed, let haptic else { return }
                BrandHaptics.fire(haptic)
            }
    }

    private func scale(for configuration: Configuration) -> CGFloat {
        guard configuration.isPressed else { return 1 }
        return reduceMotion ? 1 : pressedScale
    }

    private func opacity(for configuration: Configuration) -> Double {
        configuration.isPressed ? pressedOpacity : 1
    }
}

/// Plain bounce without the dim — useful for icon-only buttons where
/// fading is too much.
struct BouncyIconButtonStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.92

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(scale(for: configuration))
            .brandAnimation(BrandMotion.nudge, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed { BrandHaptics.fire(.light) }
            }
    }

    private func scale(for configuration: Configuration) -> CGFloat {
        guard configuration.isPressed else { return 1 }
        return reduceMotion ? 1 : pressedScale
    }
}

// MARK: - Project-owned sensory feedback (R8)

extension View {
    /// Project-owned wrapper around `.sensoryFeedback(_:trigger:)` that
    /// also honors the in-app Haptics toggle (`BrandHaptics.isEnabled`).
    ///
    /// `.sensoryFeedback` only respects the *system* haptics setting, so
    /// a bare call would keep firing even after the user turns haptics
    /// off in the app's settings. Route all new `.sensoryFeedback` call
    /// sites through this so the toggle stays authoritative.
    ///
    /// ```swift
    /// SomeControl()
    ///   .brandSensoryFeedback(.selection, trigger: selectedID)
    /// ```
    @ViewBuilder
    func brandSensoryFeedback<T: Equatable>(
        _ feedback: SensoryFeedback,
        trigger: T
    ) -> some View {
        if BrandHaptics.isEnabled {
            self.sensoryFeedback(feedback, trigger: trigger)
        } else {
            self
        }
    }

    /// Haptic-only press feedback for glass controls. Apple's interactive
    /// glass (`.glassEffect(.interactive())`) already supplies the visual
    /// press response, so glass controls should NOT stack `.scaleEffect`
    /// or `PressableButtonStyle` — they only need the haptic. This is the
    /// one-liner for that: a light selection tick on press, gated by the
    /// in-app Haptics toggle.
    ///
    /// ```swift
    /// GlassChip().glassPressFeedback(isPressed)
    /// ```
    func glassPressFeedback(_ trigger: Bool) -> some View {
        brandSensoryFeedback(.selection, trigger: trigger)
    }
}
