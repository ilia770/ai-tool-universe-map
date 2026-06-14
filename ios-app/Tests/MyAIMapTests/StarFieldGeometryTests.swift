import Testing
import simd
@testable import MyAIMap

@Suite("StarFieldGeometry — ambient backdrop placement")
struct StarFieldGeometryTests {

    @Test func positionsReturnsExactlyCount() {
        #expect(StarFieldGeometry.positions(count: 220, shellRadius: 120, seed: 1).count == 220)
        #expect(StarFieldGeometry.positions(count: 1, shellRadius: 120, seed: 1).count == 1)
        #expect(StarFieldGeometry.positions(count: 0, shellRadius: 120, seed: 1).isEmpty)
    }

    @Test func everyPointLengthWithinJitterBand() {
        let radius: Float = 120
        let jitter = StarFieldGeometry.radiusJitter
        let lower = radius * (1 - jitter)
        let upper = radius * (1 + jitter)
        for point in StarFieldGeometry.positions(count: 300, shellRadius: radius, seed: 7) {
            let length = simd_length(point)
            #expect(length >= lower - 1e-3)
            #expect(length <= upper + 1e-3)
        }
    }

    @Test func sameSeedIsDeterministic() {
        let a = StarFieldGeometry.positions(count: 220, shellRadius: 120, seed: 42)
        let b = StarFieldGeometry.positions(count: 220, shellRadius: 120, seed: 42)
        #expect(a == b)
    }

    @Test func differentSeedShiftsTheBand() {
        let a = StarFieldGeometry.positions(count: 220, shellRadius: 120, seed: 42)
        let b = StarFieldGeometry.positions(count: 220, shellRadius: 120, seed: 99)
        // Fibonacci placement is shared; the LCG jitter must differ, so the
        // arrays are not identical.
        #expect(a != b)
    }

    @Test func pointsSpanAllOctants() {
        let points = StarFieldGeometry.positions(count: 220, shellRadius: 120, seed: 3)
        #expect(points.contains { $0.x > 0 })
        #expect(points.contains { $0.x < 0 })
        #expect(points.contains { $0.y > 0 })
        #expect(points.contains { $0.y < 0 })
        #expect(points.contains { $0.z > 0 })
        #expect(points.contains { $0.z < 0 })
    }

    @Test func shellRadiusIsBeyondCameraMaxDistance() {
        // Stars must sit outside the playable volume at all zoom levels.
        #expect(StarFieldGeometry.shellRadius > CameraController.maxDistance)
    }
}
