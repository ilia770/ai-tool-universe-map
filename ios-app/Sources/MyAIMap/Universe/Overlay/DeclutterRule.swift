import Foundation
import CoreGraphics

// MARK: - OrbRole

/// Semantic role of a node in the universe.  Determines default visibility
/// priority in the declutter pass.
enum OrbRole: Sendable {
    case core       // The central Founder-OS hub (orbit 0).
    case category   // Category ring badges.
    case tool       // Individual tool nodes inside a pocket.
}

// MARK: - NodeVisibilityInput

/// Per-node input bundle for `DeclutterRule.decide`.
struct NodeVisibilityInput: Sendable {
    /// Unique tool / category identifier.
    var id: String
    /// Semantic role used to derive base visibility.
    var role: OrbRole
    /// Concentric orbit index (0 = core, 1/2/3 = inner/middle/outer tool rings).
    var orbit: Int
    /// Whether this is the currently selected / focused node.
    var isSelected: Bool
    /// Whether this node belongs to the currently open pocket category.
    var inOpenPocket: Bool
    /// Depth-based size scale from `UniverseProjection.depthScale`
    /// (clamped to [0.6, 1.6]; 1.0 ≈ reference distance of 18 world units).
    var depthScale: CGFloat
    /// 2D projected screen position (origin top-left).
    var screen: CGPoint
}

// MARK: - DeclutterRule

/// Pure, deterministic node-visibility arbiter.
///
/// **Overview mode** — only category badges and the core hub are emitted;
/// all tool nodes are hidden *except* the single selected tool (always visible).
///
/// **Pocket mode** — the open category's tool nodes become fully visible,
/// distance-faded via `ToolLabelFade`; core and category badges stay visible;
/// every other category's tool nodes fade to 0.
///
/// After base opacity is computed, a screen-space collision pass reduces the
/// lower-priority badge in each overlapping pair (within `collisionRadiusPt`
/// points) by multiplying its opacity by `0.25`.
///
/// Imports: Foundation, CoreGraphics only — no SwiftUI, no RealityKit.
enum DeclutterRule {

    // MARK: - Public API

    /// Compute per-node opacities.
    ///
    /// - Parameters:
    ///   - mode: Current camera framing mode.
    ///   - nodes: All visible-candidate nodes with their projected attributes.
    ///   - collisionRadiusPt: Screen-space radius (pts) for overlap detection.
    ///   - openCategoryID: The category whose pocket is currently open
    ///     (non-nil only when `mode == .pocket`).  When `nil` in pocket mode
    ///     the open-pocket check falls back to `node.inOpenPocket`.
    ///
    /// - Returns: `[id: opacity]` mapping for every input node, clamped [0, 1].
    static func decide(
        mode: ViewMode,
        nodes: [NodeVisibilityInput],
        collisionRadiusPt: CGFloat = 36,
        openCategoryID: String? = nil
    ) -> [String: CGFloat] {

        // 1. Compute base opacity for each node.
        var result: [String: CGFloat] = [:]
        for node in nodes {
            result[node.id] = baseOpacity(node: node, mode: mode, openCategoryID: openCategoryID)
        }

        // 2. Screen-space collision arbitration on the emitted set.
        applyCollisionReduction(nodes: nodes, opacities: &result, radius: collisionRadiusPt)

        // 3. Final clamp [0, 1].
        for key in result.keys {
            result[key] = min(1, max(0, result[key] ?? 0))
        }

        return result
    }

    // MARK: - Base opacity

    private static func baseOpacity(
        node: NodeVisibilityInput,
        mode: ViewMode,
        openCategoryID: String?
    ) -> CGFloat {

        // The selected node is always visible regardless of mode.
        if node.isSelected { return 1.0 }

        switch node.role {
        case .core:
            // Core hub is always visible.
            return 1.0

        case .category:
            // Category badges are visible in both overview and pocket.
            return 1.0

        case .tool:
            return toolOpacity(node: node, mode: mode, openCategoryID: openCategoryID)
        }
    }

    private static func toolOpacity(
        node: NodeVisibilityInput,
        mode: ViewMode,
        openCategoryID: String?
    ) -> CGFloat {
        switch mode {
        case .overview, .node:
            // Overview (and node-focus): tool labels hidden unless selected
            // (handled above).
            return 0.0

        case .pocket:
            // Determine whether this tool is inside the open pocket.
            let inOpen: Bool = node.inOpenPocket
            if inOpen {
                // Fade by camera distance, derived from depthScale.
                // depthScale = referenceDistance / distance
                // → distance = referenceDistance / depthScale
                let referenceDistance: Float = 18.0
                let depthScaleClamped = max(node.depthScale, 0.001)
                let distance = referenceDistance / Float(depthScaleClamped)
                return CGFloat(ToolLabelFade.opacity(distance: distance))
            } else {
                // Other categories' tools fade toward 0.
                return 0.0
            }
        }
    }

    // MARK: - Screen-space collision

    /// Priority: selected (4) > category (3) > inner orbit / smaller orbit (2+)
    /// > outer orbit (1).  Higher value = higher priority = survives overlap.
    private static func priority(node: NodeVisibilityInput) -> Int {
        if node.isSelected { return 100 }
        switch node.role {
        case .core:     return 50
        case .category: return 30
        case .tool:     return max(1, 20 - node.orbit)   // orbit 1 → 19, orbit 3 → 17
        }
    }

    /// Reduce the opacity of lower-priority nodes that overlap a higher-priority
    /// badge in screen space.  Pairs within `radius` points are arbitrated;
    /// the loser is multiplied by 0.25 (not zeroed, preserving faint hints).
    private static func applyCollisionReduction(
        nodes: [NodeVisibilityInput],
        opacities: inout [String: CGFloat],
        radius: CGFloat
    ) {
        // Only consider nodes that are actually being emitted.
        let visible = nodes.filter { (opacities[$0.id] ?? 0) > 0 }
        let radiusSq = radius * radius

        for i in 0..<visible.count {
            for j in (i + 1)..<visible.count {
                let a = visible[i]
                let b = visible[j]

                let dx = a.screen.x - b.screen.x
                let dy = a.screen.y - b.screen.y
                guard dx * dx + dy * dy < radiusSq else { continue }

                // Overlap detected: reduce the lower-priority node.
                let pa = priority(node: a)
                let pb = priority(node: b)

                if pa >= pb {
                    opacities[b.id] = (opacities[b.id] ?? 0) * 0.25
                } else {
                    opacities[a.id] = (opacities[a.id] ?? 0) * 0.25
                }
            }
        }
    }
}
