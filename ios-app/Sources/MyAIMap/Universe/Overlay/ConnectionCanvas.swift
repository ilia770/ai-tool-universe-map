import SwiftUI

// MARK: - ConnectionCanvas

/// Anti-aliased edge overlay drawn in a SwiftUI `Canvas`. Callers supply
/// projected screen-space endpoints each frame so edges re-route
/// automatically when a pocket opens or the camera moves — no world-space
/// state lives here.
///
/// Each edge is rendered as a gently curved quadratic Bézier with constant
/// screen-pixel width. Opacity = `EdgeOpacity.resolved` (depth × confidence
/// × selection emphasis). A tap within 10 pt of any edge triggers
/// `onTapEdge(index)` so the caller can look up the relationship reason via
/// `RelationshipReason.connectedBecause`.
struct ConnectionCanvas: View {

    // MARK: - Configuration

    /// Default stroke width in screen points.
    private static let strokeWidth: CGFloat = 1.2

    /// Tap hit-test radius in screen points.
    private static let tapRadius: CGFloat = 10

    /// Quadratic Bézier sag as a fraction of segment length.
    /// A small value (0.08) produces a subtle, natural-looking curve.
    private static let sagFraction: CGFloat = 0.08

    // MARK: - Inputs

    let edges: [ProjectedEdge]
    let onTapEdge: (Int) -> Void

    // MARK: - Internal state

    /// True when at least one edge is focused (drives opacity de-emphasis).
    private var anyFocused: Bool { edges.contains { $0.touchesFocus } }

    // MARK: - Body

    var body: some View {
        Canvas { ctx, _ in
            let focused = anyFocused
            for edge in edges {
                guard edge.depthScale > 0 else { continue }
                let opacity = EdgeOpacity.resolved(edge, focused: focused)
                guard opacity > 0.005 else { continue }

                var path = Path()
                path.move(to: edge.a)
                path.addQuadCurve(
                    to: edge.b,
                    control: controlPoint(a: edge.a, b: edge.b)
                )

                ctx.stroke(
                    path,
                    with: .color(.white.opacity(opacity)),
                    style: StrokeStyle(
                        lineWidth: Self.strokeWidth,
                        lineCap: .round
                    )
                )
            }
        }
        .allowsHitTesting(true)
        .contentShape(Rectangle())
        .onTapGesture { location in
            handleTap(at: location)
        }
    }

    // MARK: - Hit-testing

    private func handleTap(at location: CGPoint) {
        // Find the closest tappable edge within the threshold.
        // Skip invisible edges — mirrors the draw guard in body.
        let focused = anyFocused
        var bestIndex: Int? = nil
        var bestDist = CGFloat.greatestFiniteMagnitude

        for (i, edge) in edges.enumerated() {
            guard EdgeOpacity.resolved(edge, focused: focused) > 0.005 else { continue }
            let ctrl = controlPoint(a: edge.a, b: edge.b)
            let dist = EdgeHitTest.distanceToQuadCurve(
                point: location, a: edge.a, b: edge.b, sag: ctrl
            )
            if dist < bestDist {
                bestDist = dist
                bestIndex = i
            }
        }

        if let idx = bestIndex, bestDist <= Self.tapRadius {
            onTapEdge(idx)
        }
    }

    // MARK: - Geometry helpers

    /// Quadratic Bézier control point: perpendicular sag at midpoint.
    private func controlPoint(a: CGPoint, b: CGPoint) -> CGPoint {
        let mx = (a.x + b.x) * 0.5
        let my = (a.y + b.y) * 0.5
        let dx = b.x - a.x
        let dy = b.y - a.y
        let len = (dx * dx + dy * dy).squareRoot()
        guard len > 0 else { return CGPoint(x: mx, y: my) }
        // Perpendicular direction (rotated 90°).
        let px = -dy / len
        let py =  dx / len
        let sag = len * Self.sagFraction
        return CGPoint(x: mx + px * sag, y: my + py * sag)
    }

}
