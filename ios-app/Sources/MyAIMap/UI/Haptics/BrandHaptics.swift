#if canImport(UIKit)
import UIKit
#endif

/// Public haptic API surface. Five intent-named cases cover everything
/// the app does. Internally routes to `UIFeedbackGenerator` for the
/// simple cases and to `CoreHapticsEngine` for the rich pocket-reveal
/// cue that needs a custom AHAP pattern.
enum BrandHaptic {
    /// Tool tap, chip select. Soft impact.
    case light

    /// Pocket open, segmented control snap. Medium impact.
    case medium

    /// Heavy "landed" feedback — confirm classify, successful import.
    case heavy

    /// Notification success — JSON import succeeded.
    case success

    /// Notification warning — JSON import failed, rate-limited.
    case warning

    /// Notification error — unrecoverable failure (data corruption).
    case error
}

/// Single entry point. `BrandHaptics.fire(.medium)` is the only call
/// sites should ever make. The implementation handles
/// `accessibilityShouldDifferentiateWithoutColor`-style preferences,
/// reduce-motion is unrelated to haptics, but a future settings toggle
/// can flip this off centrally.
enum BrandHaptics {

    /// Set to `false` from the settings screen to disable all haptics
    /// app-wide. Default `true`.
    nonisolated(unsafe) static var isEnabled: Bool = true

    /// Pre-warm the generators that the next gesture will use. Generators
    /// not pre-warmed produce a ~50 ms delay on the first tap. Call this
    /// from `onAppear` on the screen that will fire haptics.
    @MainActor
    static func prepare(_ kinds: BrandHaptic...) {
        guard isEnabled else { return }
        #if canImport(UIKit)
        for kind in kinds {
            switch kind {
            case .light:
                Self.impactSoft.prepare()
            case .medium:
                Self.impactMedium.prepare()
            case .heavy:
                Self.impactHeavy.prepare()
            case .success, .warning, .error:
                Self.notification.prepare()
            }
        }
        #endif
    }

    /// Fires the haptic. No-op outside iOS and when disabled.
    @MainActor
    static func fire(_ kind: BrandHaptic) {
        guard isEnabled else { return }
        #if canImport(UIKit)
        switch kind {
        case .light:
            Self.impactSoft.impactOccurred()
        case .medium:
            Self.impactMedium.impactOccurred()
        case .heavy:
            Self.impactHeavy.impactOccurred()
        case .success:
            Self.notification.notificationOccurred(.success)
        case .warning:
            Self.notification.notificationOccurred(.warning)
        case .error:
            Self.notification.notificationOccurred(.error)
        }
        #endif
    }

    #if canImport(UIKit)
    @MainActor private static let impactSoft = UIImpactFeedbackGenerator(style: .soft)
    @MainActor private static let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    @MainActor private static let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    @MainActor private static let notification = UINotificationFeedbackGenerator()
    #endif
}
