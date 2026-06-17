import Foundation
import CoreGraphics

// MARK: - EdgeKind

/// Structural role of a connection edge. Mirrors web `ConnectionLines` edge
/// categories (spine / branch / inferred).
enum EdgeKind: Sendable {
    /// Core → category ring link. Structurally prominent.
    case spine
    /// Category → tool node link.
    case branch
    /// Inferred relationship edge; opacity scales with confidence.
    case inferred
}

// MARK: - ProjectedEdge

/// A single rendered edge expressed in screen-space. Callers project world
/// positions each frame and hand this in; `ConnectionCanvas` never owns
/// world-space state, so edges re-route automatically when a pocket opens.
struct ProjectedEdge: Sendable {
    var a: CGPoint
    var b: CGPoint
    var kind: EdgeKind
    /// Inferred-edge confidence in [0, 1]. Ignored for spine / branch.
    var confidence: CGFloat
    /// min(depthScale(a), depthScale(b)) from `UniverseProjection.depthScale`.
    var depthScale: CGFloat
    /// True when this edge connects a node that is currently focused (selected).
    var touchesFocus: Bool
}

// MARK: - EdgeOpacity

/// Pure opacity ladder for connection edges — a rule-for-rule port of the
/// web `ConnectionLines` colour constants. Foundation + CoreGraphics only,
/// so it is fully headless-testable.
///
/// Ladder (base values before depth × selection modifiers):
///   spine     0.28  (core → category; structural backbone)
///   branch    0.10  (category → tool; secondary mesh)
///   inferred  0.06 + confidence × 0.30  (dynamic; scaled by confidence)
///
/// Depth: multiply by `edge.depthScale` so far edges recede.
/// Selection: when `focused` (any scene focus exists):
///   • `touchesFocus`  → ~0.60 (emphasis)
///   • not touchesFocus → ~0.05 (de-emphasise)
/// Result is clamped to [0, 1].
enum EdgeOpacity {

    // MARK: Base constants (mirrors web)

    private static let spineBase:    CGFloat = 0.28
    private static let branchBase:   CGFloat = 0.10
    private static let inferredMin:  CGFloat = 0.06
    private static let inferredRange: CGFloat = 0.30  // max added by confidence

    // MARK: Selection emphasis constants

    private static let focusedEmphasis:   CGFloat = 0.60
    private static let focusedDeemphasis: CGFloat = 0.05

    // MARK: - Public API

    /// Base opacity for an edge kind before depth and selection are applied.
    ///
    /// - Parameters:
    ///   - kind: structural role of the edge.
    ///   - confidence: inferred-edge confidence in [0, 1]; ignored for spine/branch.
    /// - Returns: opacity in [0, 1].
    static func base(_ kind: EdgeKind, confidence: CGFloat) -> CGFloat {
        switch kind {
        case .spine:
            return spineBase
        case .branch:
            return branchBase
        case .inferred:
            let c = min(max(confidence, 0), 1)
            return inferredMin + c * inferredRange
        }
    }

    /// Final resolved opacity, incorporating depth recession and selection
    /// emphasis, clamped to [0, 1].
    ///
    /// - Parameters:
    ///   - edge: the projected edge to evaluate.
    ///   - focused: `true` when any node or edge in the scene is focused.
    ///     When `false`, base × depth is returned with no emphasis modifier.
    /// - Returns: opacity in [0, 1].
    static func resolved(_ edge: ProjectedEdge, focused: Bool) -> CGFloat {
        let b: CGFloat
        if focused {
            b = edge.touchesFocus ? focusedEmphasis : focusedDeemphasis
        } else {
            b = base(edge.kind, confidence: edge.confidence)
        }
        let depth = min(max(edge.depthScale, 0), 1)
        return min(max(b * depth, 0), 1)
    }
}

// MARK: - EdgeHitTest

/// Pure point-near-curve hit-testing helpers. Exposed as a testable enum so
/// tests can assert exact geometry without instantiating `ConnectionCanvas`.
enum EdgeHitTest {

    /// Shortest distance from `point` to the line segment [a, b].
    static func distance(point: CGPoint, a: CGPoint, b: CGPoint) -> CGFloat {
        let dx = b.x - a.x
        let dy = b.y - a.y
        let lenSq = dx * dx + dy * dy
        guard lenSq > 0 else {
            // Degenerate segment — distance to point a.
            let ex = point.x - a.x
            let ey = point.y - a.y
            return (ex * ex + ey * ey).squareRoot()
        }
        // Clamp parameter t to [0, 1] for point-to-segment.
        let t = min(max(((point.x - a.x) * dx + (point.y - a.y) * dy) / lenSq, 0), 1)
        let closestX = a.x + t * dx
        let closestY = a.y + t * dy
        let ex = point.x - closestX
        let ey = point.y - closestY
        return (ex * ex + ey * ey).squareRoot()
    }

    /// Returns `true` when `point` is within `threshold` pts of segment [a, b].
    static func hits(point: CGPoint, a: CGPoint, b: CGPoint, threshold: CGFloat = 10) -> Bool {
        distance(point: point, a: a, b: b) <= threshold
    }
}
