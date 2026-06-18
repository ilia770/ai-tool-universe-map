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
