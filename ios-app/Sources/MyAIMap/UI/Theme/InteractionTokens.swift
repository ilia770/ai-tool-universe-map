import CoreGraphics

/// Cross-lane interaction constants. Literal mirror of the web build's
/// `DISMISS`, `LONG_PRESS_MS`, and `DURATION.peek` (src/playground/
/// designSystem.ts) so an iOS sheet and a web sheet dismiss and peek at
/// exactly the same thresholds. Keep these two files in lockstep.
enum InteractionTokens {
    /// Long-press threshold. Web: LONG_PRESS_MS = 420.
    static let longPressSeconds: Double = 0.42
    /// Peek present duration. Web: DURATION.peek = 400.
    static let peekSeconds: Double = 0.40
    /// Downward drag (pt) that commits a dismiss. Web: DISMISS.distancePx.
    static let dismissDistance: CGFloat = 100
    /// Release velocity (pt/ms) that commits a short flick. Web: DISMISS.velocity.
    static let dismissVelocity: CGFloat = 0.5
    /// Over-drag resistance past the axis. Web: DISMISS.resistance.
    static let dismissResistance: CGFloat = 0.25

    /// Unified dismiss contract: past distance OR a downward flick.
    static func shouldDismiss(translation: CGFloat, velocity: CGFloat) -> Bool {
        translation > dismissDistance || velocity > dismissVelocity
    }

    /// Follow downward 1:1; rubber-band any upward over-drag.
    static func rubberBand(_ dy: CGFloat) -> CGFloat {
        dy > 0 ? dy : dy * dismissResistance
    }
}
