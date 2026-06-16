import Testing
import simd
import CoreGraphics
@testable import MyAIMap

@Suite("UniverseProjection")
struct UniverseProjectionTests {
    // Camera looking down -Z from (0,0,20) at origin, 60° vfov, 390x844 portrait.
    private func cam() -> UniverseProjection.Camera {
        UniverseProjection.Camera(
            eye: SIMD3<Float>(0, 0, 20),
            target: .zero,
            up: SIMD3<Float>(0, 1, 0),
            verticalFOV: .pi / 3,
            viewport: CGSize(width: 390, height: 844)
        )
    }

    @Test func nodeAtTargetProjectsToScreenCenter() {
        let p = UniverseProjection.project(.zero, camera: cam())
        let r = try! #require(p)
        #expect(abs(r.point.x - 195) < 0.5)
        #expect(abs(r.point.y - 422) < 0.5)
        #expect(r.depthScale > 0)
    }

    @Test func nearerNodeHasLargerDepthScale() {
        let near = UniverseProjection.project(SIMD3<Float>(0, 0, 5), camera: cam())!
        let far = UniverseProjection.project(SIMD3<Float>(0, 0, -5), camera: cam())!
        #expect(near.depthScale > far.depthScale)
    }

    @Test func behindCameraReturnsNil() {
        #expect(UniverseProjection.project(SIMD3<Float>(0, 0, 25), camera: cam()) == nil)
    }

    @Test func parallaxOffsetGrowsWithDepth() {
        let p = UniverseProjection.project(SIMD3<Float>(2, 0, -8), camera: cam())!
        #expect(p.parallax.width != 0)
    }
}
