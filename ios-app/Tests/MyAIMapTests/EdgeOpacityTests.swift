import Testing
import CoreGraphics
@testable import MyAIMap

// MARK: - EdgeOpacityTests

@Suite("EdgeOpacity — opacity ladder for connection edges")
struct EdgeOpacityTests {

    // MARK: Base ladder order

    @Test func spineBaseGreaterThanBranchBase() {
        #expect(EdgeOpacity.base(.spine, confidence: 0) > EdgeOpacity.base(.branch, confidence: 0))
    }

    @Test func branchBaseGreaterThanInferredAtZeroConfidence() {
        let inferredZero = EdgeOpacity.base(.inferred, confidence: 0)
        #expect(EdgeOpacity.base(.branch, confidence: 0) > inferredZero)
    }

    @Test func inferredGrowsWithConfidence() {
        let low  = EdgeOpacity.base(.inferred, confidence: 0.0)
        let mid  = EdgeOpacity.base(.inferred, confidence: 0.5)
        let high = EdgeOpacity.base(.inferred, confidence: 1.0)
        #expect(low < mid)
        #expect(mid < high)
    }

    @Test func inferredClampsAt1WithHighConfidence() {
        // confidence 1.0 → 0.06 + 0.30 = 0.36 — well under 1; ensure it
        // doesn't exceed 1 even if caller passes confidence > 1.
        let over = EdgeOpacity.base(.inferred, confidence: 10)
        #expect(over <= 1)
    }

    @Test func baseAlwaysUnitClamped() {
        for conf: CGFloat in [0, 0.25, 0.5, 0.75, 1.0, 1.5] {
            for kind: EdgeKind in [.spine, .branch, .inferred] {
                let v = EdgeOpacity.base(kind, confidence: conf)
                #expect(v >= 0, "base(\(kind), \(conf)) = \(v) < 0")
                #expect(v <= 1, "base(\(kind), \(conf)) = \(v) > 1")
            }
        }
    }

    // MARK: resolved — no focus

    @Test func resolvedWithoutFocusUsesBaseTimesDepth() {
        let edge = ProjectedEdge(
            a: .zero, b: CGPoint(x: 100, y: 0),
            kind: .spine, confidence: 0, depthScale: 1.0, touchesFocus: false
        )
        let r = EdgeOpacity.resolved(edge, focused: false)
        let expected = EdgeOpacity.base(.spine, confidence: 0) * 1.0
        #expect(abs(r - expected) < 1e-6)
    }

    @Test func resolvedScalesDownWithLowerDepth() {
        let full = ProjectedEdge(
            a: .zero, b: CGPoint(x: 100, y: 0),
            kind: .spine, confidence: 0, depthScale: 1.0, touchesFocus: false
        )
        let half = ProjectedEdge(
            a: .zero, b: CGPoint(x: 100, y: 0),
            kind: .spine, confidence: 0, depthScale: 0.5, touchesFocus: false
        )
        #expect(EdgeOpacity.resolved(full, focused: false) > EdgeOpacity.resolved(half, focused: false))
    }

    @Test func resolvedDepthZeroProducesZeroOpacity() {
        let edge = ProjectedEdge(
            a: .zero, b: CGPoint(x: 100, y: 0),
            kind: .spine, confidence: 0, depthScale: 0, touchesFocus: false
        )
        #expect(EdgeOpacity.resolved(edge, focused: false) == 0)
    }

    // MARK: resolved — with focus

    @Test func resolvedFocusedEdgeBrighter() {
        let touching = ProjectedEdge(
            a: .zero, b: CGPoint(x: 100, y: 0),
            kind: .inferred, confidence: 0.5, depthScale: 1.0, touchesFocus: true
        )
        let notTouching = ProjectedEdge(
            a: .zero, b: CGPoint(x: 100, y: 0),
            kind: .inferred, confidence: 0.5, depthScale: 1.0, touchesFocus: false
        )
        let rFocus    = EdgeOpacity.resolved(touching,    focused: true)
        let rDeemph   = EdgeOpacity.resolved(notTouching, focused: true)
        #expect(rFocus > rDeemph)
    }

    @Test func resolvedNonFocusEdgeDropsNear005() {
        let notTouching = ProjectedEdge(
            a: .zero, b: CGPoint(x: 100, y: 0),
            kind: .spine, confidence: 0, depthScale: 1.0, touchesFocus: false
        )
        let r = EdgeOpacity.resolved(notTouching, focused: true)
        // Should be ~0.05 (focusedDeemphasis × depthScale=1.0).
        #expect(abs(r - 0.05) < 1e-6)
    }

    @Test func resolvedFocusedTouchingNear060() {
        let touching = ProjectedEdge(
            a: .zero, b: CGPoint(x: 100, y: 0),
            kind: .spine, confidence: 0, depthScale: 1.0, touchesFocus: true
        )
        let r = EdgeOpacity.resolved(touching, focused: true)
        #expect(abs(r - 0.60) < 1e-6)
    }

    @Test func resolvedAlwaysUnitClamped() {
        let scales: [CGFloat] = [0, 0.3, 0.6, 1.0, 1.5]
        for depth in scales {
            for kind: EdgeKind in [.spine, .branch, .inferred] {
                for focused in [false, true] {
                    for touches in [false, true] {
                        let edge = ProjectedEdge(
                            a: .zero, b: .zero,
                            kind: kind, confidence: 0.8,
                            depthScale: depth, touchesFocus: touches
                        )
                        let r = EdgeOpacity.resolved(edge, focused: focused)
                        #expect(r >= 0, "resolved < 0 at depth=\(depth) focused=\(focused)")
                        #expect(r <= 1, "resolved > 1 at depth=\(depth) focused=\(focused)")
                    }
                }
            }
        }
    }

    // MARK: resolved — near-edge depth boost (fix: upper clamp removed)

    /// A `touchesFocus` edge at depthScale 1.6 (near) must yield at least as
    /// high an opacity as the same edge at depthScale 1.0. In practice the
    /// near edge overshoots the ceiling and is capped at 1.0, so the assertion
    /// is >= (equal when both hit the ceiling).
    @Test func resolvedNearEdgeAtLeastAsBrightAsMidEdge() {
        let near = ProjectedEdge(
            a: .zero, b: CGPoint(x: 100, y: 0),
            kind: .spine, confidence: 0, depthScale: 1.6, touchesFocus: true
        )
        let mid = ProjectedEdge(
            a: .zero, b: CGPoint(x: 100, y: 0),
            kind: .spine, confidence: 0, depthScale: 1.0, touchesFocus: true
        )
        #expect(EdgeOpacity.resolved(near, focused: true) >= EdgeOpacity.resolved(mid, focused: true))
    }

    /// A non-focus far edge (depthScale 0.6) must be dimmer than the same edge
    /// at depthScale 1.0 so depth recession still works when unfocused.
    @Test func resolvedFarEdgeDimmerThanMidEdge() {
        let far = ProjectedEdge(
            a: .zero, b: CGPoint(x: 100, y: 0),
            kind: .spine, confidence: 0, depthScale: 0.6, touchesFocus: false
        )
        let mid = ProjectedEdge(
            a: .zero, b: CGPoint(x: 100, y: 0),
            kind: .spine, confidence: 0, depthScale: 1.0, touchesFocus: false
        )
        #expect(EdgeOpacity.resolved(far, focused: false) < EdgeOpacity.resolved(mid, focused: false))
    }
}

// MARK: - EdgeHitTestTests

@Suite("EdgeHitTest — point-near-segment geometry")
struct EdgeHitTestTests {

    @Test func pointOnSegmentDistanceIsZero() {
        // Horizontal segment from (0,0) to (100,0); point at midpoint (50,0).
        let d = EdgeHitTest.distance(
            point: CGPoint(x: 50, y: 0),
            a: CGPoint(x: 0, y: 0),
            b: CGPoint(x: 100, y: 0)
        )
        #expect(d < 1e-6)
    }

    @Test func pointDirectlyAboveSegmentMidpointDistanceIsYOffset() {
        let d = EdgeHitTest.distance(
            point: CGPoint(x: 50, y: 5),
            a: CGPoint(x: 0, y: 0),
            b: CGPoint(x: 100, y: 0)
        )
        #expect(abs(d - 5) < 1e-6)
    }

    @Test func pointFarFromSegmentReturnsTrueDistance() {
        let d = EdgeHitTest.distance(
            point: CGPoint(x: 50, y: 200),
            a: CGPoint(x: 0, y: 0),
            b: CGPoint(x: 100, y: 0)
        )
        #expect(abs(d - 200) < 1e-6)
    }

    @Test func hitsReturnsTrueWhenClose() {
        #expect(EdgeHitTest.hits(
            point: CGPoint(x: 50, y: 5),
            a: CGPoint(x: 0, y: 0),
            b: CGPoint(x: 100, y: 0),
            threshold: 10
        ))
    }

    @Test func hitsReturnsFalseWhenFar() {
        #expect(!EdgeHitTest.hits(
            point: CGPoint(x: 50, y: 100),
            a: CGPoint(x: 0, y: 0),
            b: CGPoint(x: 100, y: 0),
            threshold: 10
        ))
    }

    @Test func degenerateSegmentDistanceIsDistanceToEndpoint() {
        // Both endpoints at origin — distance should be 5.
        let d = EdgeHitTest.distance(
            point: CGPoint(x: 3, y: 4),
            a: CGPoint(x: 0, y: 0),
            b: CGPoint(x: 0, y: 0)
        )
        #expect(abs(d - 5) < 1e-6)
    }

    @Test func pointPastEndpointClampsToBEndpoint() {
        // Point is to the right of b(100,0); closest point on segment is b.
        let d = EdgeHitTest.distance(
            point: CGPoint(x: 110, y: 0),
            a: CGPoint(x: 0, y: 0),
            b: CGPoint(x: 100, y: 0)
        )
        #expect(abs(d - 10) < 1e-6)
    }
}

// MARK: - EdgeHitTest Bézier tests

@Suite("EdgeHitTest — quadratic Bézier distance")
struct EdgeHitTestBezierTests {

    // Horizontal edge from (0,0) to (200,0).
    // Control point sits at the apex: midpoint (100,0) offset perpendicularly
    // by sag. With sagFraction=0.08 and length=200, sag offset = 16 pt,
    // so control = (100, -16) (perpendicular is -y for the 90° rotation used
    // in ConnectionCanvas).
    // The Bézier apex (t=0.5) evaluates to:
    //   x = 0.25*0 + 2*0.25*100 + 0.25*200 = 100
    //   y = 0.25*0 + 2*0.25*(-16) + 0.25*0 = -8
    // So the apex is at (100, -8).

    private let edgeA  = CGPoint(x: 0,   y: 0)
    private let edgeB  = CGPoint(x: 200, y: 0)
    private let sagCtrl = CGPoint(x: 100, y: -16)  // perpendicular sag

    /// A point placed exactly at the computed Bézier apex (100, -8) must be
    /// within the 10 pt tap threshold.
    @Test func pointAtCurveApexIsWithinThreshold() {
        let apex = CGPoint(x: 100, y: -8)
        let d = EdgeHitTest.distanceToQuadCurve(
            point: apex, a: edgeA, b: edgeB, sag: sagCtrl
        )
        #expect(d < 10, "Expected distance < 10 pt at apex, got \(d)")
    }

    /// A point far from the curve (200 pt away perpendicularly) must exceed
    /// the 10 pt threshold.
    @Test func pointFarFromCurveExceedsThreshold() {
        let farPoint = CGPoint(x: 100, y: 200)
        let d = EdgeHitTest.distanceToQuadCurve(
            point: farPoint, a: edgeA, b: edgeB, sag: sagCtrl
        )
        #expect(d > 10, "Expected distance > 10 pt far from curve, got \(d)")
    }
}
