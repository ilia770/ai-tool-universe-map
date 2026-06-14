import Testing
import simd
@testable import MyAIMap

@Suite("LinkGeometry — structural connection-line math")
struct LinkGeometryTests {

    @Test func positionIsMidpoint() {
        let from = SIMD3<Float>(1, 2, 3)
        let to = SIMD3<Float>(5, 8, -1)
        let t = LinkGeometry.transform(from: from, to: to, thickness: 0.02)
        #expect(simd_length(t.position - (from + to) * 0.5) < 1e-4)
    }

    @Test func lengthAxisScaleEqualsDistance() {
        let from = SIMD3<Float>(0, 0, 0)
        let to = SIMD3<Float>(3, 4, 0) // distance 5
        let thickness: Float = 0.013
        let t = LinkGeometry.transform(from: from, to: to, thickness: thickness)
        // +Y is the length axis.
        #expect(abs(t.scale.y - 5) < 1e-4)
        // Perpendicular axes carry the thickness.
        #expect(abs(t.scale.x - thickness) < 1e-4)
        #expect(abs(t.scale.z - thickness) < 1e-4)
    }

    @Test func rotationMapsLengthAxisOntoDirection() {
        let from = SIMD3<Float>(-2, 1, 4)
        let to = SIMD3<Float>(6, -3, 2)
        let t = LinkGeometry.transform(from: from, to: to, thickness: 0.02)
        let rotated = t.rotation.act(LinkGeometry.lengthAxis)
        let direction = simd_normalize(to - from)
        // Rotated length axis should align with the from→to direction.
        #expect(simd_dot(rotated, direction) > 0.9999)
    }

    @Test func degenerateZeroLengthDoesNotCrash() {
        let p = SIMD3<Float>(2, 2, 2)
        let t = LinkGeometry.transform(from: p, to: p, thickness: 0.02)
        #expect(simd_length(t.position - p) < 1e-4)
        #expect(t.scale.y == 0)
        // Identity-ish rotation, finite values only.
        let rotated = t.rotation.act(LinkGeometry.lengthAxis)
        #expect(rotated.x.isFinite && rotated.y.isFinite && rotated.z.isFinite)
    }
}
