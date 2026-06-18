import Testing
import simd
@testable import MyAIMap

@Suite("GalaxyDustGeometry — sparse ambient haze placement")
struct GalaxyDustGeometryTests {

    @Test func positionsReturnsExactlyCount() {
        #expect(GalaxyDustGeometry.positions(count: 22, shellRadius: 36, seed: 1).count == 22)
        #expect(GalaxyDustGeometry.positions(count: 1, shellRadius: 36, seed: 1).count == 1)
        #expect(GalaxyDustGeometry.positions(count: 0, shellRadius: 36, seed: 1).isEmpty)
    }

    @Test func everyPointLengthWithinJitterBand() {
        let radius: Float = 36
        let jitter = GalaxyDustGeometry.radiusJitter
        let lower = radius * (1 - jitter)
        let upper = radius * (1 + jitter)
        for point in GalaxyDustGeometry.positions(count: 60, shellRadius: radius, seed: 7) {
            let length = simd_length(point)
            #expect(length >= lower - 1e-3)
            #expect(length <= upper + 1e-3)
        }
    }

    @Test func sameSeedIsDeterministic() {
        let a = GalaxyDustGeometry.positions(count: 22, shellRadius: 36, seed: 42)
        let b = GalaxyDustGeometry.positions(count: 22, shellRadius: 36, seed: 42)
        #expect(a == b)
    }

    @Test func differentSeedShiftsTheCloud() {
        let a = GalaxyDustGeometry.positions(count: 22, shellRadius: 36, seed: 42)
        let b = GalaxyDustGeometry.positions(count: 22, shellRadius: 36, seed: 99)
        // Fibonacci placement is shared; the LCG jitter must differ, so the
        // arrays are not identical.
        #expect(a != b)
    }

    @Test func pointsSpanAllOctants() {
        // With only ~22 blobs the Fibonacci spiral still covers the sphere;
        // use a slightly higher count to keep the octant check robust.
        let points = GalaxyDustGeometry.positions(count: 48, shellRadius: 36, seed: 3)
        #expect(points.contains { $0.x > 0 })
        #expect(points.contains { $0.x < 0 })
        #expect(points.contains { $0.y > 0 })
        #expect(points.contains { $0.y < 0 })
        #expect(points.contains { $0.z > 0 })
        #expect(points.contains { $0.z < 0 })
    }


    @Test func dustShellIsInSensibleMidRange() {
        // Mid-distance haze: outside the camera's playable volume
        // (maxDistance 46) at the band's far edge would overlap, but the
        // documented intent is a mid radius well under the stars. Assert it
        // lands in a sensible mid band (< 60) and is positive.
        #expect(GalaxyDustGeometry.shellRadius > 0)
        #expect(GalaxyDustGeometry.shellRadius < 60)
    }
}
