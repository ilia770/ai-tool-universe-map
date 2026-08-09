import Foundation
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
            .brandAnimation(BrandMotion.press, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                guard isPressed, let haptic else { return }
                BrandHaptics.fire(haptic)
            }
    }

    private func scale(for configuration: Configuration) -> CGFloat {
        BrandMotion.pressScale(
            pressedScale,
            isPressed: configuration.isPressed,
            reduceMotion: reduceMotion
        )
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
            .brandAnimation(BrandMotion.press, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed { BrandHaptics.fire(.light) }
            }
    }

    private func scale(for configuration: Configuration) -> CGFloat {
        BrandMotion.pressScale(
            pressedScale,
            isPressed: configuration.isPressed,
            reduceMotion: reduceMotion
        )
    }
}

/// Press behavior for controls whose label owns interactive native glass.
/// iOS 26 supplies the visual response; older systems get the shared surface
/// scale fallback. Haptics continue to route through the app-wide gate.
struct GlassControlButtonStyle: ButtonStyle {
    static let fallbackPressedScale: CGFloat = 0.97
    static let fallbackPressedOpacity: Double = 0.9

    var haptic: BrandHaptic?
    var ownsInteractiveGlass = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(Self.resolvedScale(
                isPressed: configuration.isPressed,
                reduceMotion: reduceMotion,
                usesNativeGlassResponse: usesNativeGlassResponse
            ))
            .opacity(Self.resolvedOpacity(
                isPressed: configuration.isPressed,
                usesNativeGlassResponse: usesNativeGlassResponse
            ))
            .brandAnimation(BrandMotion.press, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                guard isPressed, let haptic else { return }
                BrandHaptics.fire(haptic)
            }
    }

    static func resolvedScale(
        isPressed: Bool,
        reduceMotion: Bool,
        arguments: [String] = ProcessInfo.processInfo.arguments,
        usesNativeGlassResponse: Bool
    ) -> CGFloat {
        guard !usesNativeGlassResponse else { return 1 }
        return BrandMotion.pressScale(
            fallbackPressedScale,
            isPressed: isPressed,
            reduceMotion: reduceMotion,
            arguments: arguments
        )
    }

    static func resolvedOpacity(
        isPressed: Bool,
        usesNativeGlassResponse: Bool
    ) -> Double {
        guard isPressed, !usesNativeGlassResponse else { return 1 }
        return fallbackPressedOpacity
    }

    static func nativeGlassResponseEnabled(
        platformSupportsNativeGlass: Bool,
        reduceTransparency: Bool,
        reduceMotion: Bool,
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> Bool {
        platformSupportsNativeGlass
            && !reduceTransparency
            && !BrandMotion.isMotionDisabled(reduceMotion: reduceMotion, arguments: arguments)
    }

    private var usesNativeGlassResponse: Bool {
        ownsInteractiveGlass && Self.nativeGlassResponseEnabled(
            platformSupportsNativeGlass: supportsNativeGlass,
            reduceTransparency: reduceTransparency,
            reduceMotion: reduceMotion
        )
    }

    private var supportsNativeGlass: Bool {
        if #available(iOS 26.0, *) { true } else { false }
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

    /// Haptic-only feedback where native interactive glass is guaranteed to
    /// own the visual response. Cross-version buttons use
    /// `GlassControlButtonStyle` for the iOS 18–25 scale fallback.
    ///
    /// ```swift
    /// GlassChip().glassPressFeedback(isPressed)
    /// ```
    func glassPressFeedback(_ trigger: Bool) -> some View {
        brandSensoryFeedback(.selection, trigger: trigger)
    }
}
