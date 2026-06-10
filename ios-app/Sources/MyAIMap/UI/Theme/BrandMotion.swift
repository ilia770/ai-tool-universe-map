import SwiftUI

/// Animation curves. Four named cases cover everything the app does;
/// every other use of `.animation(...)` should reach for one of these
/// before declaring a new curve.
enum BrandMotion {
    /// Sheets, modals, the tool detail card sliding in.
    /// Mirrors the web build's `cubic-bezier(0.16, 1, 0.3, 1)`.
    static let entry: Animation = .spring(response: 0.42, dampingFraction: 0.85)

    /// Button taps, chip selection, toggle flips. Short and crisp.
    static let nudge: Animation = .spring(response: 0.28, dampingFraction: 0.72)

    /// Camera focus moves, pocket transition lerps. Smooth over time.
    static let flow: Animation = .smooth(duration: 0.36)

    /// Ambient glow loops on the founder core and selected nodes.
    /// Repeats forever, auto-reverses, gentle ease.
    static let breath: Animation = .easeInOut(duration: 4.0).repeatForever(autoreverses: true)

    /// Resolves a curve to its reduce-motion safe counterpart. Pass the
    /// SwiftUI `@Environment(\.accessibilityReduceMotion)` value.
    static func resolved(_ animation: Animation, reduceMotion: Bool) -> Animation {
        reduceMotion ? .linear(duration: 0.001) : animation
    }
}

/// View modifier that gates an animation behind reduce-motion. Lets
/// call sites write `.animation(.brandFlow, value: state)` without
/// branching on the environment in every view.
extension View {
    func brandAnimation<V: Equatable>(_ animation: Animation, value: V) -> some View {
        modifier(BrandAnimationModifier(animation: animation, value: value))
    }
}

private struct BrandAnimationModifier<V: Equatable>: ViewModifier {
    let animation: Animation
    let value: V
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.animation(BrandMotion.resolved(animation, reduceMotion: reduceMotion), value: value)
    }
}
