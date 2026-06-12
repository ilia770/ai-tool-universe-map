import Testing
import simd
@testable import MyAIMap

@Suite("PocketTransition — persistent-scene framing + scale math")
struct PocketTransitionTests {

    @Test func framingsMatchWebCameraOffsets() {
        let target = SIMD3<Float>(3, -1, 2)
        #expect(PocketTransition.framing(mode: .overview, target: target) == target + SIMD3<Float>(0, 6.3, 19.5))
        #expect(PocketTransition.framing(mode: .pocket, target: target) == target + SIMD3<Float>(0, 6.8, 19.0))
        #expect(PocketTransition.framing(mode: .node, target: target) == target + SIMD3<Float>(0, 5.0, 15.5))
    }

    @Test func durationsMatchWebSmoothTime() {
        #expect(PocketTransition.duration == 0.55)
        #expect(PocketTransition.reducedDuration == 0.04)
    }

    @Test func toolScaleReproducesLegacyMeshRadii() {
        // Pre-persistent-scene meshes were generated at the state radius;
        // now base mesh radius × scale must land on the same visual size.
        for orbit in 0...3 {
            let base = PocketTransition.baseToolRadius(orbit: orbit)
            #expect(abs(base * PocketTransition.toolNodeScale(orbit: orbit, selected: true, pocketed: false)
                - (0.46 + Float(orbit) * 0.055)) < 1e-5)
            // Pocketed keeps the PHASE_2_PLAN 1.18× boost on top of the
            // pocket radius, exactly like the rebuild-era scene.
            #expect(abs(base * PocketTransition.toolNodeScale(orbit: orbit, selected: false, pocketed: true)
                - (0.32 + Float(orbit) * 0.04) * PocketShellGeometry.pocketNodeScale) < 1e-5)
            #expect(PocketTransition.toolNodeScale(orbit: orbit, selected: false, pocketed: false) == 1)
        }
    }

    @Test func anchorScaleMatchesLegacyRadii() {
        #expect(abs(PocketTransition.baseAnchorRadius * PocketTransition.anchorScale(selected: true)
            - PocketTransition.selectedAnchorRadius) < 1e-5)
        #expect(PocketTransition.anchorScale(selected: false) == 1)
    }
}
