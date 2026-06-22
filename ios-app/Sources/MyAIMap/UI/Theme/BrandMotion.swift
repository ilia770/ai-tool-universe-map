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

    // MARK: - Chat-first redesign tokens (see motion-haptics spec)

    /// Per-token streamed-text fade-in. Driven by the stream's chunk cadence.
    static let stream: Animation = .easeOut(duration: 0.18)

    /// Blinking streaming caret. Repeating — guard behind reduce-motion.
    static let cursor: Animation = .easeInOut(duration: 0.62).repeatForever(autoreverses: true)

    /// Pre-first-token "thinking" dots/glow. Repeating — guard behind reduce-motion.
    static let thinking: Animation = .easeInOut(duration: 1.1).repeatForever(autoreverses: true)

    /// Tool-card group fade+rise after text completes. Softer/slower than `entry`.
    static let reveal: Animation = .spring(response: 0.5, dampingFraction: 0.86)

    /// Liquid Glass morphs (card→orbit, chat⇄universe). Semantic alias of `flow`;
    /// glass must morph on a one-shot smooth curve, never a repeating one.
    static let morph: Animation = flow

    /// Map count badge / node-arrival pop. Under-damped → deliberate overshoot.
    static let pillPop: Animation = .spring(response: 0.34, dampingFraction: 0.55)

    /// Composer height growth (1→6 lines). High damping → no wobble on a field.
    static let composerGrow: Animation = .spring(response: 0.30, dampingFraction: 0.88)

    /// Resolves a curve to its reduce-motion safe counterpart. Pass the
    /// SwiftUI `@Environment(\.accessibilityReduceMotion)` value.
    static func resolved(_ animation: Animation, reduceMotion: Bool) -> Animation {
        reduceMotion ? .linear(duration: 0.001) : animation
    }
}

/// Reduce-motion-safe `withAnimation` for imperative action blocks, so call
/// sites stop using bare `withAnimation(BrandMotion.*)` which bypasses the
/// resolver (review finding R9).
@MainActor
func withBrandAnimation<Result>(
    _ animation: Animation,
    reduceMotion: Bool,
    _ body: () throws -> Result
) rethrows -> Result {
    try withAnimation(BrandMotion.resolved(animation, reduceMotion: reduceMotion), body)
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
