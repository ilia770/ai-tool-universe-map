import Foundation

/// Frame-rate-independent easing for the overlay. Honors Reduce Motion. Pure.
enum UniverseMotion {
    /// Web signature cubic-bezier(0.16,1,0.3,1) approximated as ease-out-expo.
    static func easeOutExpo(_ t: Float) -> Float {
        t >= 1 ? 1 : 1 - powf(2, -10 * t)
    }
    /// Frame-rate-independent exponential approach toward `target`.
    static func approach(_ current: Float, _ target: Float, dt: TimeInterval,
                         k: Float, reduceMotion: Bool) -> Float {
        if reduceMotion { return target }
        let a = 1 - expf(-k * Float(dt))
        return current + (target - current) * a
    }
}
