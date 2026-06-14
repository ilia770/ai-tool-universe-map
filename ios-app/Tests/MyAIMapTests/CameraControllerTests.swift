import CoreGraphics
import RealityKit
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

    @Test func orbitPitchClampPreventsCameraFlip() {
        #expect(CameraController.clampedOrbitPitch(-2) == CameraController.minOrbitPitch)
        #expect(CameraController.clampedOrbitPitch(0.2) == 0.2)
        #expect(CameraController.clampedOrbitPitch(2) == CameraController.maxOrbitPitch)
    }

    @Test func orbitYawRotatesAroundVerticalAxis() {
        let adjusted = CameraController.orbitAdjusted(
            SIMD3<Float>(0, 0, 1),
            yaw: .pi / 2,
            pitch: 0
        )

        #expect(abs(adjusted.x + 1) < 0.001)
        #expect(abs(adjusted.y) < 0.001)
        #expect(abs(adjusted.z) < 0.001)
    }

    @Test func orbitAdjustmentPreservesDistanceFromOrigin() {
        let point = SIMD3<Float>(2, 3, -4)
        let adjusted = CameraController.orbitAdjusted(point, yaw: 0.8, pitch: -0.3)

        #expect(abs(simd_length(point) - simd_length(adjusted)) < 0.001)
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

    // MARK: - Pinch gesture lifecycle (regression: mid-pinch re-attach)

    @Test @MainActor func pinchFromRestDolliesByAbsoluteMagnification() {
        let controller = CameraController()
        let camera = PerspectiveCamera()
        controller.attach(camera, mode: .overview, target: .zero)
        let base = simd_length(camera.position)

        controller.pinchChanged(magnification: 1.0)
        #expect(abs(simd_length(camera.position) - base) < 0.001)

        controller.pinchChanged(magnification: 2.0)
        #expect(abs(simd_length(camera.position) - CameraController.clampedDistance(base / 2)) < 0.001)
    }

    @Test @MainActor func midPinchReattachDoesNotApplyAccumulatedMagnification() {
        let controller = CameraController()
        let camera = PerspectiveCamera()
        controller.attach(camera, mode: .overview, target: .zero)
        controller.pinchChanged(magnification: 1.0)
        controller.pinchChanged(magnification: 2.5)

        // Proximity auto-enter rebuilds the scene mid-pinch: attach()
        // runs again while the magnify gesture is still ongoing.
        let pocketTarget = SIMD3<Float>(4, 0, -2)
        controller.attach(camera, mode: .pocket, target: pocketTarget)
        let framing = simd_length(CameraController.focusEye(for: .pocket, target: pocketTarget) - pocketTarget)

        // The next update still reports the accumulated 2.5x; the camera
        // must stay at the pocket framing distance (no jump to min).
        controller.pinchChanged(magnification: 2.5)
        #expect(abs(simd_length(camera.position - pocketTarget) - framing) < 0.001)

        // Further pinching zooms relative to the re-capture point
        // (effective magnification 3.0 / 2.5 = 1.2).
        controller.pinchChanged(magnification: 3.0)
        let expected = CameraController.clampedDistance(framing / (3.0 / 2.5))
        #expect(abs(simd_length(camera.position - pocketTarget) - expected) < 0.001)
    }

    @Test @MainActor func pinchEndedResetsMagnificationReference() {
        let controller = CameraController()
        let camera = PerspectiveCamera()
        controller.attach(camera, mode: .overview, target: .zero)
        controller.pinchChanged(magnification: 1.0)
        controller.pinchChanged(magnification: 2.5)
        controller.pinchEnded()

        // A fresh gesture starting at ~1.0 behaves exactly like a pinch
        // from rest: 2.0 halves the new resting distance.
        let resting = simd_length(camera.position)
        controller.pinchChanged(magnification: 1.0)
        #expect(abs(simd_length(camera.position) - resting) < 0.001)

        controller.pinchChanged(magnification: 2.0)
        #expect(abs(simd_length(camera.position) - CameraController.clampedDistance(resting / 2)) < 0.001)
    }

    // MARK: - Drag orbit

    @Test @MainActor func orbitChangedRotatesCameraPreservingDistance() {
        let controller = CameraController()
        let camera = PerspectiveCamera()
        controller.attach(camera, mode: .overview, target: .zero)
        let before = simd_length(camera.position - controller.target)

        controller.orbitChanged(translation: CGSize(width: 120, height: 0))
        let after = simd_length(camera.position - controller.target)

        // Pure rotation: the distance from target is unchanged...
        #expect(abs(before - after) < 0.001)
        // ...and the eye actually moved (horizontal drag swept yaw).
        #expect(simd_length(camera.position - CameraController.focusEye(for: .overview, target: .zero)) > 0.001)
    }

    @Test @MainActor func orbitPitchClampsUnderLargeVerticalDrag() {
        let controller = CameraController()
        let camera = PerspectiveCamera()
        controller.attach(camera, mode: .overview, target: .zero)

        // A huge vertical drag would over-rotate; pitch must clamp so the
        // camera never flips. The orbited eye must land exactly where a
        // pure rotation at maxOrbitPitch puts the (un-orbited) base eye —
        // proving the drag pitch was clamped, not applied raw.
        controller.orbitChanged(translation: CGSize(width: 0, height: 100_000))

        let baseEye = CameraController.focusEye(for: .overview, target: .zero)
        let expected = CameraController.orbitAdjusted(
            baseEye,
            yaw: 0,
            pitch: CameraController.maxOrbitPitch
        )
        #expect(simd_length(camera.position - expected) < 0.001)
    }

    @Test @MainActor func orbitEndedKeepsOrbitedPosition() {
        let controller = CameraController()
        let camera = PerspectiveCamera()
        controller.attach(camera, mode: .overview, target: .zero)

        controller.orbitChanged(translation: CGSize(width: 120, height: 40))
        let orbited = camera.position
        controller.orbitEnded()

        // No snap-back: the camera stays exactly where the drag left it.
        #expect(simd_length(camera.position - orbited) < 0.001)

        // A second drag continues from the kept orbit (baseline = current),
        // so zero translation is a no-op rather than a reset to head-on.
        controller.orbitChanged(translation: .zero)
        #expect(simd_length(camera.position - orbited) < 0.001)
    }

    @Test @MainActor func retargetResetsOrbitToHeadOn() {
        let controller = CameraController()
        let camera = PerspectiveCamera()
        controller.attach(camera, mode: .overview, target: .zero)
        controller.orbitChanged(translation: CGSize(width: 200, height: 80))
        controller.orbitEnded()

        let pocketTarget = SIMD3<Float>(4, 0, -2)
        controller.retarget(mode: .pocket, target: pocketTarget, reduceMotion: true)

        // After retarget, a zero-translation drag must recompute the eye at
        // the head-on framing for the new pocket (orbit reset to 0).
        controller.orbitChanged(translation: .zero)
        let expected = CameraController.focusEye(for: .pocket, target: pocketTarget)
        #expect(simd_length(camera.position - expected) < 0.001)
    }

    @Test @MainActor func orbitComposesWithPinchDolly() {
        let controller = CameraController()
        let camera = PerspectiveCamera()
        controller.attach(camera, mode: .overview, target: .zero)

        // Pinch to dolly in, then orbit: the orbit must preserve the
        // dollied distance, not snap back to the framing distance.
        controller.pinchChanged(magnification: 1.0)
        controller.pinchChanged(magnification: 2.0)
        controller.pinchEnded()
        let dollied = simd_length(camera.position - controller.target)

        controller.orbitChanged(translation: CGSize(width: 90, height: 0))
        #expect(abs(simd_length(camera.position - controller.target) - dollied) < 0.001)
    }
}
