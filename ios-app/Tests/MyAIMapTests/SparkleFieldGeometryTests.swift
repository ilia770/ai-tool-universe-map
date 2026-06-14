import Testing
import simd
@testable import MyAIMap

@Suite("SparkleFieldGeometry — pocket-world particle placement")
struct SparkleFieldGeometryTests {

    @Test func positionsReturnsExactlyCount() {
        #expect(SparkleFieldGeometry.positions(count: 54, seed: 1).count == 54)
        #expect(SparkleFieldGeometry.positions(count: 1, seed: 1).count == 1)
        #expect(SparkleFieldGeometry.positions(count: 0, seed: 1).isEmpty)
    }

    @Test func defaultCountMatchesWebSparkles() {
        #expect(SparkleFieldGeometry.sparkleCount == 54)
        #expect(SparkleFieldGeometry.positions().count == 54)
    }

    @Test func everyPointInsideTheBox() {
        let half = SparkleFieldGeometry.halfExtents
        for point in SparkleFieldGeometry.positions(count: 500, seed: 7) {
            #expect(abs(point.x) <= half.x + 1e-3)
            #expect(abs(point.y) <= half.y + 1e-3)
            #expect(abs(point.z) <= half.z + 1e-3)
        }
    }

    @Test func sameSeedIsDeterministic() {
        let a = SparkleFieldGeometry.positions(count: 54, seed: 42)
        let b = SparkleFieldGeometry.positions(count: 54, seed: 42)
        #expect(a == b)
    }

    @Test func differentSeedShiftsTheCloud() {
        let a = SparkleFieldGeometry.positions(count: 54, seed: 42)
        let b = SparkleFieldGeometry.positions(count: 54, seed: 99)
        #expect(a != b)
    }

    @Test func pointsSpanAllOctants() {
        let points = SparkleFieldGeometry.positions(count: 200, seed: 3)
        #expect(points.contains { $0.x > 0 })
        #expect(points.contains { $0.x < 0 })
        #expect(points.contains { $0.y > 0 })
        #expect(points.contains { $0.y < 0 })
        #expect(points.contains { $0.z > 0 })
        #expect(points.contains { $0.z < 0 })
    }

    @Test func halfExtentsMatchWebDerivedVolume() {
        // scale={[POCKET_WORLD_RADIUS*2.18, 2.8, POCKET_WORLD_RADIUS*1.36]}
        // halved, with POCKET_WORLD_RADIUS = 7.
        let half = SparkleFieldGeometry.halfExtents
        #expect(abs(half.x - 7.63) < 0.05)
        #expect(abs(half.y - 1.4) < 0.01)
        #expect(abs(half.z - 4.76) < 0.05)
    }
}
