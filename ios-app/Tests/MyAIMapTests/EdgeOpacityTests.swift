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
