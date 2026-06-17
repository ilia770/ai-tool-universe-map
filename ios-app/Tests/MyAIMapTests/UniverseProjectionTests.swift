import Testing
import simd
import CoreGraphics
@testable import MyAIMap

@Suite("UniverseProjection — 3D-to-2D projector for overlay nodes")
struct UniverseProjectionTests {

    // Axis-aligned overview camera: eye directly in front of origin along +Z.
    // target = origin, eye = (0, 0, 19.5).
    private let overviewCamera = CameraState(
        eye: SIMD3<Float>(0, 0, 19.5),
        target: .zero,
        fovYRadians: Float.pi / 3,   // 60°
        orbitYaw: 0,
        orbitPitch: 0
    )
    private let viewport = CGSize(width: 390, height: 844)

    // MARK: 1. Point at target projects near viewport center

    @Test func targetProjectsNearCenter() {
        let result = UniverseProjection.project(
            world: .zero,
            camera: overviewCamera,
            viewport: viewport
        )
        #expect(result.isVisible)
        // Allow up to 2pt from the geometric center.
        #expect(abs(result.screen.x - viewport.width / 2) < 2)
        #expect(abs(result.screen.y - viewport.height / 2) < 2)
    }

    // MARK: 2. Point at/behind camera returns isVisible == false

    @Test func pointAtEyeIsNotVisible() {
        // Placing the world point exactly at the eye position means it is
        // on or behind the near plane — w should be <= 0.
        let result = UniverseProjection.project(
            world: overviewCamera.eye,
            camera: overviewCamera,
            viewport: viewport
        )
        #expect(!result.isVisible)
    }

    @Test func pointBehindCameraIsNotVisible() {
        // Behind the camera along -Z (further from origin than the eye).
        let result = UniverseProjection.project(
            world: SIMD3<Float>(0, 0, 30),
            camera: overviewCamera,
            viewport: viewport
        )
        #expect(!result.isVisible)
    }

    // MARK: 3. depthScale monotonically decreasing, clamped to [0.6, 1.6]

    @Test func depthScaleMonotonicallyDecreasing() {
        let distances: [Float] = [1, 5, 10, 20, 50, 100]
        var prev = UniverseProjection.depthScale(distance: distances[0])
        for d in distances.dropFirst() {
            let here = UniverseProjection.depthScale(distance: d)
            #expect(here <= prev + 1e-6)
            prev = here
        }
    }

    @Test func depthScaleClamped() {
        for d: Float in [0.001, 0.1, 1, 5, 10, 50, 1000] {
            let s = UniverseProjection.depthScale(distance: d)
            #expect(s >= 0.6 - 1e-6)
            #expect(s <= 1.6 + 1e-6)
        }
    }

    // MARK: 4. Symmetric world points (±x) project to symmetric screen x

    @Test func symmetricPointsProjectSymmetrically() {
        let left = UniverseProjection.project(
            world: SIMD3<Float>(-3, 0, 0),
            camera: overviewCamera,
            viewport: viewport
        )
        let right = UniverseProjection.project(
            world: SIMD3<Float>(3, 0, 0),
            camera: overviewCamera,
            viewport: viewport
        )
        #expect(left.isVisible)
        #expect(right.isVisible)
        let cx = Double(viewport.width) / 2
        let leftDelta = left.screen.x - cx
        let rightDelta = right.screen.x - cx
        // Mirror: sum should be ~0; magnitudes within 1pt.
        #expect(abs(leftDelta + rightDelta) < 1)
        #expect(abs(abs(leftDelta) - abs(rightDelta)) < 1)
    }

    // MARK: 5. Doubling viewport width keeps a centred point centred

    @Test func widerViewportKeepsCenterCentered() {
        let wideViewport = CGSize(width: viewport.width * 2, height: viewport.height)
        let result = UniverseProjection.project(
            world: .zero,
            camera: overviewCamera,
            viewport: wideViewport
        )
        #expect(result.isVisible)
        #expect(abs(result.screen.x - wideViewport.width / 2) < 2)
        #expect(abs(result.screen.y - wideViewport.height / 2) < 2)
    }

    // MARK: 6. Parallax magnitude grows with orbit yaw, shrinks as depthScale→1

    @Test func parallaxGrowsWithYaw() {
        let lowYaw = CameraState(
            eye: SIMD3<Float>(0, 0, 19.5),
            target: .zero,
            fovYRadians: Float.pi / 3,
            orbitYaw: 0.1,
            orbitPitch: 0
        )
        let highYaw = CameraState(
            eye: SIMD3<Float>(0, 0, 19.5),
            target: .zero,
            fovYRadians: Float.pi / 3,
            orbitYaw: 0.6,
            orbitPitch: 0
        )
        // Use a far point so depthScale < 1, which lets parallax be non-zero.
        let farPoint = SIMD3<Float>(0, 0, -5)
        let pLow  = UniverseProjection.project(world: farPoint, camera: lowYaw,  viewport: viewport)
        let pHigh = UniverseProjection.project(world: farPoint, camera: highYaw, viewport: viewport)
        let magLow  = abs(pLow.parallax.width)
        let magHigh = abs(pHigh.parallax.width)
        #expect(magHigh > magLow)
    }

    @Test func parallaxShrinkWhenDepthScaleNearOne() {
        // At the reference distance, depthScale ≈ 1, so (1 - depthScale) ≈ 0
        // and parallax should be close to zero regardless of yaw.
        let referenceDistance: Float = 18.0   // near the reference used by depthScale
        let nearTarget = SIMD3<Float>(0, 0, 19.5 - referenceDistance)
        let angledCam = CameraState(
            eye: SIMD3<Float>(0, 0, 19.5),
            target: .zero,
            fovYRadians: Float.pi / 3,
            orbitYaw: 0.5,
            orbitPitch: 0.3
        )
        let result = UniverseProjection.project(world: nearTarget, camera: angledCam, viewport: viewport)
        // Near-reference means depthScale is near 1, so parallax magnitude is small.
        let mag = sqrt(result.parallax.width * result.parallax.width + result.parallax.height * result.parallax.height)
        #expect(mag < 20)  // generous bound: what matters is it's much less than far points
    }
}
