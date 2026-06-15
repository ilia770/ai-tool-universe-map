import Foundation

/// Pure breathing math for the open pocket-shell (backlog 22): the slow
/// ±1.8 % scale wobble and the gentle yaw sway dropped from slice 3, mirroring
/// the web `PocketWorldShell` (`sin(elapsed * 0.32)` scale, `sin(elapsed *
/// 0.28)` rotation). Kept Foundation-only so the curve is unit-tested in
/// `ShellBreathingTests`; `ShellBreathingSystem` applies it per frame.
enum ShellBreathing {

    /// ±1.8 % — matches the web shell wobble.
    static let scaleAmplitude: Float = 0.018
    /// Yaw sway amplitude in radians (~2.3°) — subtle, just enough to feel
    /// alive without reading as spin.
    static let yawAmplitude: Float = 0.04

    /// Angular frequencies (rad/s), mirroring the web elapsed-time multipliers
    /// so the two platforms breathe at the same cadence.
    private static let scaleFrequency: Float = 0.32
    private static let yawFrequency: Float = 0.28

    /// Multiplicative scale factor at `time`. `1` at t=0 and whenever
    /// reduce-motion is on, so applying it is always safe.
    static func scale(time: TimeInterval, reduceMotion: Bool) -> Float {
        guard !reduceMotion else { return 1 }
        return 1 + scaleAmplitude * sin(scaleFrequency * Float(time))
    }

    /// Yaw angle (radians) at `time`. `0` at t=0 and under reduce-motion.
    static func yaw(time: TimeInterval, reduceMotion: Bool) -> Float {
        guard !reduceMotion else { return 0 }
        return yawAmplitude * sin(yawFrequency * Float(time))
    }
}
