import Testing
import simd
@testable import MyAIMap

@Suite("CameraController — drei parity math")
struct CameraControllerTests {

    @Test func distanceClampMatchesWebMinMax() {
        // Web: <CameraControls minDistance={7.5} maxDistance={46}>
        #expect(CameraController.clampedDistance(5) == 7.5)
        #expect(CameraController.clampedDistance(7.5) == 7.5)
        #expect(CameraController.clampedDistance(20) == 20)
        #expect(CameraController.clampedDistance(46) == 46)
        #expect(CameraController.clampedDistance(60) == 46)
    }

    @Test func focusOffsetsMatchWebPerViewMode() {
        // Web CameraController.tsx: overview y+6.3 z+19.5,
        // pocket y+6.8 z+19.0, node y+5.0 z+15.5.
        let target = SIMD3<Float>(2, 1, -3)
        #expect(CameraController.focusEye(for: .overview, target: target) == target + SIMD3<Float>(0, 6.3, 19.5))
        #expect(CameraController.focusEye(for: .pocket, target: target) == target + SIMD3<Float>(0, 6.8, 19.0))
        #expect(CameraController.focusEye(for: .node, target: target) == target + SIMD3<Float>(0, 5.0, 15.5))
    }

    @Test func lookRotationPointsCameraForwardAtTarget() {
        let eye = SIMD3<Float>(0, 5, 10)
        let target = SIMD3<Float>(0, 0, 0)
        let rotation = CameraController.lookRotation(eye: eye, target: target)
        // RealityKit cameras look down -Z: rotating (0,0,-1) must yield
        // the normalized eye->target direction.
        let forward = rotation.act(SIMD3<Float>(0, 0, -1))
        let expected = simd_normalize(target - eye)
        #expect(simd_length(forward - expected) < 0.001)
    }

    @Test func lookRotationKeepsCameraUpright() {
        let eye = SIMD3<Float>(4, 6, 12)
        let target = SIMD3<Float>(-1, 0, 2)
        let rotation = CameraController.lookRotation(eye: eye, target: target)
        let up = rotation.act(SIMD3<Float>(0, 1, 0))
        // World-up component must stay positive (no roll).
        #expect(up.y > 0)
    }

    @Test func lookRotationSurvivesDegenerateEyeOnTarget() {
        let point = SIMD3<Float>(1, 2, 3)
        let rotation = CameraController.lookRotation(eye: point, target: point)
        // Must not produce NaNs.
        let forward = rotation.act(SIMD3<Float>(0, 0, -1))
        #expect(forward.x.isFinite && forward.y.isFinite && forward.z.isFinite)
    }

    @Test func pinchDollyScalesAndClampsDistance() {
        // distance' = clamp(base / magnification, 7.5, 46)
        #expect(CameraController.dollyDistance(base: 20, magnification: 2) == 10)
        #expect(CameraController.dollyDistance(base: 20, magnification: 0.5) == 40)
        #expect(CameraController.dollyDistance(base: 20, magnification: 10) == 7.5)
        #expect(CameraController.dollyDistance(base: 20, magnification: 0.1) == 46)
        // Guard against divide-by-zero.
        let degenerate = CameraController.dollyDistance(base: 20, magnification: 0)
        #expect(degenerate == 46)
    }
}
