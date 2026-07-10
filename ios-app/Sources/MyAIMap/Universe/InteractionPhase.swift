import Foundation

/// Unified interaction phase for the 3D universe (RK.4,
/// docs/UNIVERSE_STATE_MACHINE.md §2). One vocabulary over the previously
/// fragmented flags — `CameraRigController.isTransitioning`,
/// `UniverseGestureController.dragInteracting/pinchInteracting`, and the
/// mode's gesture gate — so gesture legality is decided in one place.
enum InteractionPhase: Equatable, Sendable {
    /// Detail/chat overlay owns the screen; map gestures are gated off.
    case overlayInteracting
    /// A camera fly-to is in flight; new gestures are locked out (a new
    /// SELECTION still interrupts via the rig's generation guard).
    case cameraAnimating
    /// Finger down orbiting the camera.
    case dragging
    /// Pinch dolly in progress.
    case pinching
    case idle

    /// Single derivation point. Priority: overlay > camera flight > active
    /// gesture > idle — mirrors the legacy guard order exactly
    /// (`mode.allowsMapGestures, !cameraRig.isTransitioning`).
    static func derive(
        mode: UniverseMode,
        isTransitioning: Bool,
        isDragging: Bool,
        isPinching: Bool
    ) -> InteractionPhase {
        if !mode.allowsMapGestures { return .overlayInteracting }
        if isTransitioning { return .cameraAnimating }
        if isDragging { return .dragging }
        if isPinching { return .pinching }
        return .idle
    }

    /// Whether map tap/drag/pinch may begin in this phase.
    var allowsMapGestures: Bool {
        switch self {
        case .overlayInteracting, .cameraAnimating:
            return false
        case .dragging, .pinching, .idle:
            return true
        }
    }
}
