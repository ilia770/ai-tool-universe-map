import Foundation
import SwiftUI

/// Pure motion math for per-frame lerps and discrete transitions.
///
/// **Reduce-Motion contract**
/// - `transition(reduceMotion:)` wraps `BrandMotion.resolved` — the single
///   RM gate. Never add a second `@Environment(\.accessibilityReduceMotion)`
///   check elsewhere for UniverseMotion concerns.
/// - `smoothing(k:dt:)` is RM-agnostic by design (callers own dt). When
///   reduce-motion is active, callers should use `transition(reduceMotion:)`
///   for SwiftUI animations; for TimelineView lerps, pass a large dt (e.g.
///   1_000) or use `smoothing(k:dt:reduceMotion:)` which returns 1.0 directly.
enum UniverseMotion {

    // MARK: — Per-frame smoothing

    /// Frame-rate-independent lerp factor: `1 − exp(−k·dt)`, clamped to [0, 1].
    ///
    /// At 60 Hz dt ≈ 0.0167; at 120 Hz dt ≈ 0.0083. Composing two half-steps
    /// equals one full step exactly (exponential-decay residual property), so
    /// the animation feels identical at both frame rates.
    ///
    /// - Parameters:
    ///   - k: Stiffness (higher = faster response). Typical range 4–20.
    ///   - dt: Frame delta in seconds from TimelineView.
    static func smoothing(k: Float, dt: Float) -> Float {
        let raw = 1 - Foundation.exp(-k * dt)
        return min(max(raw, 0), 1)
    }

    /// Reduce-Motion-aware overload. Returns 1.0 immediately when reduced,
    /// otherwise delegates to `smoothing(k:dt:)`.
    static func smoothing(k: Float, dt: Float, reduceMotion: Bool) -> Float {
        reduceMotion ? 1 : smoothing(k: k, dt: dt)
    }

    // MARK: — Linear interpolation

    /// Standard linear interpolation. `t` is not clamped — callers may
    /// clamp with `smoothing(k:dt:)` which already returns [0, 1].
    static func lerp(_ a: Float, _ b: Float, _ t: Float) -> Float {
        a + (b - a) * t
    }

    // MARK: — Ease-out-expo curve

    /// Approximates the web `cubic-bezier(0.16, 1, 0.3, 1)` ease-out-expo
    /// used for discrete UI transitions (pocket open/close, node focus).
    ///
    /// Properties guaranteed:
    /// - `easeOutExpo(0) == 0`, `easeOutExpo(1) == 1`.
    /// - Monotonically increasing on [0, 1].
    /// - Front-loaded: value at 0.5 is well above 0.5.
    static func easeOutExpo(_ x: Float) -> Float {
        guard x > 0 else { return 0 }
        guard x < 1 else { return 1 }
        return 1 - Foundation.pow(2, -10 * x)
    }

    // MARK: — Pulse / breathing

    /// Sine-based breathing oscillator that stays within `1 ± amplitude`.
    ///
    /// Typical use: selected-orb glow, `amplitude` 0.05, `period` 1.4 s.
    ///
    /// - Parameters:
    ///   - time: Elapsed seconds (from TimelineView date offset).
    ///   - amplitude: Half-range of oscillation (e.g. 0.05 for ±5 %).
    ///   - period: Full oscillation duration in seconds.
    ///   - reduceMotion: When true, returns exactly 1.0 (no animation).
    static func pulse(time: Float, amplitude: Float, period: Float, reduceMotion: Bool) -> Float {
        guard !reduceMotion else { return 1.0 }
        let phase = (2 * Float.pi * time) / period
        return 1 + amplitude * Foundation.sin(phase)
    }

    // MARK: — SwiftUI Animation accessor

    /// Returns the appropriate `Animation` for discrete transitions,
    /// routing through `BrandMotion.resolved` as the single Reduce-Motion gate.
    static func transition(reduceMotion: Bool) -> Animation {
        BrandMotion.resolved(BrandMotion.entry, reduceMotion: reduceMotion)
    }
}
