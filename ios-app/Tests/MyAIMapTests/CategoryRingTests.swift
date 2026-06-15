import Testing
import simd
@testable import MyAIMap

/// Phase C visual slices (backlog 23 rings, 24 selection pulse, 27 founder
/// halo). The rings reuse the already-tested `PocketShellGeometry.torus`,
/// and the pulse/halo are RealityKit animations that aren't unit-testable
/// without live entities — so these tests only pin the new numeric
/// constants to sane ranges and confirm the ring's torus parameters yield
/// valid geometry.
// @MainActor: the constants under test are static members of `UniverseView`
// (a SwiftUI `View`, hence MainActor-isolated). Swift 6 strict concurrency on
// the Xcode 16.x CI toolchain rejects reading them from a nonisolated `@Test`
// context; isolating the suite to the main actor fixes the build. (The local
// 26.x gate doesn't flag it, so this only surfaced in iOS CI.)
@Suite("Phase C visuals — ring / pulse / halo constants")
@MainActor
struct CategoryRingTests {

    @Test func categoryRingConstantsAreSane() {
        // Ring should encircle the overview tool cloud (orbit radii top out
        // ~1.98 from the anchor) without ballooning past the category spread.
        #expect(UniverseView.categoryRingRadius > 1.98)
        #expect(UniverseView.categoryRingRadius < 4.55) // < categoryRadiusX
        // Thin tube → reads as a drawn orbit line, not a donut.
        #expect(UniverseView.categoryRingTube > 0)
        #expect(UniverseView.categoryRingTube <= 0.02)
        // Low opacity whisper, not a competing solid.
        #expect(UniverseView.categoryRingOpacity > 0)
        #expect(UniverseView.categoryRingOpacity < 0.3)
    }

    @Test func categoryRingTorusGeneratesValidGeometry() {
        // The ring builds its mesh from the tested torus generator; assert
        // the ring's own parameters produce a well-formed, on-surface torus.
        let torus = PocketShellGeometry.torus(
            radius: UniverseView.categoryRingRadius,
            tube: UniverseView.categoryRingTube,
            radialSegments: 6,
            tubularSegments: 96
        )
        #expect(torus.positions.count == 7 * 97)
        #expect(torus.indices.count == 6 * 96 * 2 * 3)
        let r = UniverseView.categoryRingRadius
        let t = UniverseView.categoryRingTube
        for p in torus.positions {
            let ringDist = simd_length(SIMD2<Float>(simd_length(SIMD2<Float>(p.x, p.y)) - r, p.z))
            #expect(abs(ringDist - t) < 1e-4)
        }
    }

    @Test func selectionPulseConstantsAreGentle() {
        // A subtle breath: small amplitude, slow leg — never a visible jump.
        #expect(UniverseView.selectionPulseScale > 0)
        #expect(UniverseView.selectionPulseScale <= 0.05)
        #expect(UniverseView.selectionPulseDuration >= 0.5)
    }

    @Test func founderHaloConstantsAreSane() {
        // Halo must be larger than the core node (selected radius ~0.46) so
        // it envelopes it, and frosted (low opacity) rather than solid.
        #expect(UniverseView.founderHaloRadius > 0.46)
        #expect(UniverseView.founderHaloRadius < 2.0)
        #expect(UniverseView.founderHaloOpacity > 0)
        #expect(UniverseView.founderHaloOpacity < 0.2)
        #expect(UniverseView.founderHaloBreathScale > 0)
        #expect(UniverseView.founderHaloBreathScale <= 0.1)
    }
}
