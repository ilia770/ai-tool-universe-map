import Foundation
import simd

/// Pure math for the persistent-scene pocket transition (backlog tasks
/// 15/16): camera framings per view mode, transition durations, and the
/// entity-scale factors that replace mesh regeneration. RealityKit's
/// `Entity.move(to:relativeTo:duration:timingFunction:)` does the actual
/// easing — this file owns the *where* and *how long* so the numbers stay
/// unit-testable (Foundation + simd only, like `UniverseLayout`).
enum PocketTransition {
    /// Web parity: `<CameraControls smoothTime={0.55}>`.
    static let duration: TimeInterval = 0.55
    /// Reduce-motion: near-instant, but non-zero so RealityKit still
    /// runs a real (single-frame) transform animation.
    static let reducedDuration: TimeInterval = 0.04

    /// Eye position for a framing mode. Offsets match the web
    /// CameraController exactly (overview / pocket / node). Single source
    /// of truth — `CameraController.focusEye` delegates here.
    static func framing(mode: ViewMode, target: SIMD3<Float>) -> SIMD3<Float> {
        switch mode {
        case .overview: return target + SIMD3<Float>(0, 6.3, 19.5)
        case .pocket: return target + SIMD3<Float>(0, 6.8, 19.0)
        case .node: return target + SIMD3<Float>(0, 5.0, 15.5)
        }
    }

    // MARK: - Node scale
    //
    // The persistent scene generates every sphere mesh once at its base
    // radius; selection / pocket emphasis is a uniform entity-scale change
    // (scale = desiredRadius / baseRadius), so meshes never regenerate
    // mid-transition and `Entity.move` can animate between states.

    /// Overview, unselected tool sphere radius — the radius every tool
    /// mesh is generated at.
    static func baseToolRadius(orbit: Int) -> Float {
        0.24 + Float(orbit) * 0.025
    }

    /// The radius a tool sphere should *appear* at for a given state.
    /// Mirrors the pre-persistent-scene mesh radii one-for-one.
    static func desiredToolRadius(orbit: Int, selected: Bool, pocketed: Bool) -> Float {
        let orbitRadius = Float(orbit)
        if selected { return 0.46 + orbitRadius * 0.055 }
        if pocketed { return 0.32 + orbitRadius * 0.04 }
        return baseToolRadius(orbit: orbit)
    }

    /// Uniform entity scale for a tool node: desired / base radius, times
    /// the pocket 1.18× boost (PHASE_2_PLAN step 5) when pocketed.
    static func toolNodeScale(orbit: Int, selected: Bool, pocketed: Bool) -> Float {
        var scale = desiredToolRadius(orbit: orbit, selected: selected, pocketed: pocketed)
            / baseToolRadius(orbit: orbit)
        if pocketed { scale *= PocketShellGeometry.pocketNodeScale }
        return scale
    }

    /// Category anchor radii — mesh is generated at the base radius;
    /// selection emphasis is the scale ratio below.
    static let baseAnchorRadius: Float = 0.48
    static let selectedAnchorRadius: Float = 0.74

    static func anchorScale(selected: Bool) -> Float {
        selected ? selectedAnchorRadius / baseAnchorRadius : 1
    }
}
