import Foundation
import CoreGraphics

// OrbRole is defined in DeclutterRule.swift — do NOT redefine here.

// MARK: - OrbState

/// Rendering emphasis level for a projected orb.
enum OrbState: Sendable {
    /// Standard overview framing — orb is visible but not highlighted.
    case overview
    /// The orb belongs to the currently open pocket.
    case pocket
    /// The orb is the focused / selected node.
    case selected
    /// Orb is out-of-context and should recede.
    case dimmed
}

// MARK: - ProjectedOrb

/// Fully-resolved screen-space descriptor fed to `OrbLayer`.
///
/// `Color` is not `Sendable` in all Swift 6 strict-concurrency setups
/// (it carries an internal UIColor box that isn't marked Sendable on
/// older OS SDKs). Explicit `Sendable` conformance is therefore omitted
/// from `ProjectedOrb`; callers that need to cross an isolation boundary
/// should snapshot the RGBA components separately.
import SwiftUI
struct ProjectedOrb {
    var center: CGPoint
    var depthScale: CGFloat
    var role: OrbRole
    var orbit: Int
    var state: OrbState
    var color: Color
}

// MARK: - OrbStyle

/// Pure math for orb rendering: radius ladder, emissive intensity, and
/// halo scale.  All methods are pure functions of their arguments
/// (Foundation + CoreGraphics only — no SwiftUI, no RealityKit).
///
/// **Radius derivation** — screen radii are derived from
/// `PocketTransition` world radii so there is a single source of truth:
///
/// ```
/// toolBase   = CGFloat(PocketTransition.baseToolRadius(orbit:1))   ≈ 0.265
/// coreBase   = CGFloat(PocketTransition.selectedAnchorRadius)      ≈ 0.74
/// anchorBase = CGFloat(PocketTransition.baseAnchorRadius)          ≈ 0.48
/// ```
///
/// Screen radii are those world values multiplied by a fixed projection
/// constant (`ptPerWorldUnit` = 44 pt / world-unit at the reference
/// distance of 18 units, calibrated so the overview orbit fills the
/// screen reasonably) and then scaled by `depthScale`.
enum OrbStyle {

    // MARK: - Internal calibration constant

    /// Points per world-unit at depthScale == 1 (reference distance ≈ 18 wu).
    /// Chosen so that `baseToolRadius(orbit:1) × ptPerWorldUnit ≈ 11.7 pt`,
    /// a comfortable tap-target floor in the 3D canvas overlay.
    static let ptPerWorldUnit: CGFloat = 44

    // MARK: - Screen radius

    /// Screen radius in points for an orb of `role` at `depthScale`.
    ///
    /// - `core`     → derived from `PocketTransition.selectedAnchorRadius`
    ///                (the largest anchor mesh radius — the core hub is the
    ///                biggest object in the scene).
    /// - `category` → derived from `PocketTransition.baseAnchorRadius`
    ///                (unselected category anchor radius).
    /// - `tool`     → derived from `PocketTransition.baseToolRadius(orbit:)`.
    ///
    /// All three satisfy core > category > tool at equal depth (verified
    /// in `OrbStyleTests`).
    static func screenRadius(role: OrbRole, orbit: Int, depthScale: CGFloat) -> CGFloat {
        let worldRadius: CGFloat
        switch role {
        case .core:
            worldRadius = CGFloat(PocketTransition.selectedAnchorRadius)
        case .category:
            worldRadius = CGFloat(PocketTransition.baseAnchorRadius)
        case .tool:
            worldRadius = CGFloat(PocketTransition.baseToolRadius(orbit: max(orbit, 1)))
        }
        return worldRadius * ptPerWorldUnit * depthScale
    }

    // MARK: - Emissive ramp

    /// Core brightness multiplier ∈ [0, 1].  Higher = brighter glow.
    /// Order: selected > pocket > overview > dimmed; all ≥ 0.
    static func emissive(_ state: OrbState) -> CGFloat {
        switch state {
        case .selected: return 1.00
        case .pocket:   return 0.72
        case .overview: return 0.48
        case .dimmed:   return 0.18
        }
    }

    // MARK: - Halo scale

    /// Multiplier for the additive halo radius relative to the core disc.
    /// ≥ 1.0 for all states; larger for selected so the pulse reads clearly.
    static func haloScale(_ state: OrbState) -> CGFloat {
        switch state {
        case .selected: return 1.55
        case .pocket:   return 1.35
        case .overview: return 1.20
        case .dimmed:   return 1.10
        }
    }
}
