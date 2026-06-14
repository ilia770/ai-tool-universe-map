import Foundation
import RealityKit
import simd

/// Owns the universe `PerspectiveCamera`, mirroring the web build's
/// drei `CameraControls` semantics (`src/components/AIToolUniverse3D/
/// CameraController.tsx`): clamped dolly distance, per-view-mode focus
/// offsets, smooth focus moves. The view-model never touches the
/// RealityKit graph — views forward gestures here instead.
@MainActor
final class CameraController {

    // Web parity: <CameraControls minDistance={7.5} maxDistance={46}
    // smoothTime={0.55}>.
    nonisolated static let minDistance: Float = 7.5
    nonisolated static let maxDistance: Float = 46
    nonisolated static let minOrbitPitch: Float = -0.55
    nonisolated static let maxOrbitPitch: Float = 0.55
    static let smoothTime: TimeInterval = 0.55

    private(set) weak var camera: PerspectiveCamera?
    private(set) var target: SIMD3<Float> = .zero
    private var pinchBaseDistance: Float?
    private var pinchBaseMagnification: Float?

    /// Drag-orbit translates the gesture into a yaw (horizontal) + pitch
    /// (vertical) rotation of the eye around `target`. Radians per point;
    /// tuned so a ~full-screen (~390pt) drag sweeps ~110° of yaw.
    nonisolated static let orbitSensitivity: Float = 0.005

    /// Live orbit accumulators. They persist across drags (the map stays
    /// where the user left it) but reset to 0 on a category re-frame so
    /// each pocket is presented head-on.
    private var orbitYaw: Float = 0
    private var orbitPitch: Float = 0
    /// Baselines captured on the first `.onChanged` of a drag so the whole
    /// gesture is relative to where the orbit was when the finger landed.
    private var dragBaseYaw: Float?
    private var dragBasePitch: Float?
    /// The un-orbited eye for the active framing, set wherever the camera
    /// is framed (attach / focus / retarget). Orbit rotates THIS around
    /// `target`; pinch then dollies along the resulting eye->target axis.
    private var baseEye: SIMD3<Float> = .zero

    /// nonisolated so `@State private var controller = CameraController()`
    /// compiles under Swift 6 strict concurrency (SwiftUI property
    /// initializers run in a nonisolated context). The init touches no
    /// isolated state — every property has a default value.
    nonisolated init() {}

    // MARK: - Pure math (unit-tested)

    nonisolated static func clampedDistance(_ distance: Float) -> Float {
        min(max(distance, minDistance), maxDistance)
    }

    /// Clamp drag-orbit pitch so the map can feel 3D without flipping
    /// upside down. The same pure math powers the SwiftUI preview map
    /// and can later feed the RealityKit camera rig.
    nonisolated static func clampedOrbitPitch(_ pitch: Float) -> Float {
        min(max(pitch, minOrbitPitch), maxOrbitPitch)
    }

    /// Applies a lightweight orbit transform to a world point: yaw around
    /// Y, then pitch around X. This keeps hit targets, labels, and node
    /// projection aligned while the user drags the universe.
    nonisolated static func orbitAdjusted(_ position: SIMD3<Float>, yaw: Float, pitch: Float) -> SIMD3<Float> {
        let clampedPitch = clampedOrbitPitch(pitch)
        let yawCos = cos(yaw)
        let yawSin = sin(yaw)
        let yawed = SIMD3<Float>(
            position.x * yawCos - position.z * yawSin,
            position.y,
            position.x * yawSin + position.z * yawCos
        )

        let pitchCos = cos(clampedPitch)
        let pitchSin = sin(clampedPitch)
        return SIMD3<Float>(
            yawed.x,
            yawed.y * pitchCos - yawed.z * pitchSin,
            yawed.y * pitchSin + yawed.z * pitchCos
        )
    }

    /// Eye position for a framing mode. Delegates to
    /// `PocketTransition.framing` so the offsets have one source of truth.
    nonisolated static func focusEye(for mode: ViewMode, target: SIMD3<Float>) -> SIMD3<Float> {
        PocketTransition.framing(mode: mode, target: target)
    }

    /// World-up look-at rotation. RealityKit cameras look down -Z, so
    /// the basis is (right, up, back) with back = normalize(eye - target).
    nonisolated static func lookRotation(eye: SIMD3<Float>, target: SIMD3<Float>) -> simd_quatf {
        let offset = eye - target
        guard simd_length(offset) > 1e-6 else { return simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0)) }
        let back = simd_normalize(offset)
        let worldUp = SIMD3<Float>(0, 1, 0)
        var right = simd_cross(worldUp, back)
        // Degenerate when looking straight up/down: pick a stable right.
        if simd_length(right) < 1e-6 {
            right = SIMD3<Float>(1, 0, 0)
        } else {
            right = simd_normalize(right)
        }
        let up = simd_cross(back, right)
        return simd_quatf(simd_float3x3(columns: (right, up, back)))
    }

    /// Pinch dolly: scale the gesture-start distance by 1/magnification,
    /// clamped to the web min/max. magnification <= 0 clamps to max
    /// (defensive; SwiftUI never reports it).
    nonisolated static func dollyDistance(base: Float, magnification: Float) -> Float {
        guard magnification > 1e-6 else { return maxDistance }
        return clampedDistance(base / magnification)
    }

    // MARK: - Entity control

    /// Adopt a camera entity (called from RealityView's make closure)
    /// and snap it to the framing for the given mode/target.
    func attach(_ camera: PerspectiveCamera, mode: ViewMode, target: SIMD3<Float>) {
        self.camera = camera
        self.target = target
        // A cancelled gesture never fires .onEnded; never carry a stale
        // pinch base into a freshly adopted scene.
        pinchBaseDistance = nil
        pinchBaseMagnification = nil
        let eye = Self.focusEye(for: mode, target: target)
        baseEye = eye
        // A fresh adoption frames head-on; never carry a stale orbit.
        orbitYaw = 0
        orbitPitch = 0
        dragBaseYaw = nil
        dragBasePitch = nil
        camera.position = eye
        camera.orientation = Self.lookRotation(eye: eye, target: target)
    }

    /// Smoothly re-frame on a new target (camera focus move). Duration
    /// mirrors the web smoothTime.
    func focus(on newTarget: SIMD3<Float>, mode: ViewMode, animated: Bool = true) {
        guard let camera else { return }
        target = newTarget
        let eye = Self.focusEye(for: mode, target: newTarget)
        baseEye = eye
        orbitYaw = 0
        orbitPitch = 0
        dragBaseYaw = nil
        dragBasePitch = nil
        var transform = camera.transform
        transform.translation = eye
        transform.rotation = Self.lookRotation(eye: eye, target: newTarget)
        if animated {
            camera.move(to: transform, relativeTo: camera.parent, duration: Self.smoothTime, timingFunction: .easeInOut)
        } else {
            camera.transform = transform
        }
    }

    /// Persistent-scene re-frame (backlog task 16): animate the already
    /// attached camera to a new mode/target framing instead of snapping.
    /// Resets the pinch base state under the same contract as `attach` —
    /// a category change must not carry a stale pinch reference.
    func retarget(mode: ViewMode, target: SIMD3<Float>, reduceMotion: Bool) {
        guard let camera else { return }
        self.target = target
        pinchBaseDistance = nil
        pinchBaseMagnification = nil
        let eye = PocketTransition.framing(mode: mode, target: target)
        baseEye = eye
        // Each category is framed head-on: a re-frame resets orbit to 0.
        orbitYaw = 0
        orbitPitch = 0
        dragBaseYaw = nil
        dragBasePitch = nil
        var transform = camera.transform
        transform.translation = eye
        transform.rotation = Self.lookRotation(eye: eye, target: target)
        if reduceMotion {
            // Reduce-motion: snap instantly so the camera is immediately at
            // the head-on framing (no in-flight transform animation).
            camera.transform = transform
        } else {
            camera.move(
                to: transform,
                relativeTo: camera.parent,
                duration: PocketTransition.duration,
                timingFunction: .easeInOut
            )
        }
    }

    /// Live pinch update. Captures the distance at gesture start, then
    /// dollies along the current eye->target axis with clamping.
    func pinchChanged(magnification: Float) {
        guard let camera else { return }
        let offset = camera.position - target
        let currentDistance = simd_length(offset)
        if pinchBaseDistance == nil {
            pinchBaseDistance = currentDistance
            // Capture the gesture's magnification at the same instant so
            // dollying is relative to it. On a fresh gesture this is ~1.0
            // (unchanged behavior); after a mid-pinch scene rebuild it is
            // the accumulated value, so the camera doesn't jump.
            pinchBaseMagnification = magnification
            // A focus move may still be animating; direct position writes
            // must win once the user pinches.
            camera.stopAllAnimations()
        }
        guard let base = pinchBaseDistance,
              let reference = pinchBaseMagnification,
              currentDistance > 1e-6 else { return }
        let direction = offset / currentDistance
        camera.position = target + direction * Self.dollyDistance(base: base, magnification: magnification / reference)
    }

    func pinchEnded() {
        pinchBaseDistance = nil
        pinchBaseMagnification = nil
    }

    // MARK: - Drag orbit

    /// Live drag-orbit update. Maps horizontal drag to yaw and vertical
    /// drag to pitch (clamped), rotating the framing eye around `target`.
    ///
    /// Pinch interaction: orbit rotates the *base* eye direction but keeps
    /// the camera's CURRENT distance from target, so a dolly the user
    /// applied with pinch survives an orbit (and vice-versa). `baseEye`
    /// only supplies the un-orbited DIRECTION; the radius is whatever the
    /// camera is at right now.
    func orbitChanged(translation: CGSize) {
        guard let camera else { return }
        if dragBaseYaw == nil {
            dragBaseYaw = orbitYaw
            dragBasePitch = orbitPitch
            // A focus/retarget move may still be animating; a direct
            // position write must win once the user starts dragging.
            camera.stopAllAnimations()
        }
        guard let baseYaw = dragBaseYaw, let basePitch = dragBasePitch else { return }

        orbitYaw = baseYaw + Float(translation.width) * Self.orbitSensitivity
        orbitPitch = Self.clampedOrbitPitch(basePitch + Float(translation.height) * Self.orbitSensitivity)

        // Preserve the live distance (honours any pinch dolly).
        let currentDistance = simd_length(camera.position - target)
        let baseOffset = baseEye - target
        let rotated = Self.orbitAdjusted(baseOffset, yaw: orbitYaw, pitch: orbitPitch)
        let rotatedLength = simd_length(rotated)
        guard rotatedLength > 1e-6 else { return }
        let eye = target + rotated / rotatedLength * currentDistance
        camera.position = eye
        camera.orientation = Self.lookRotation(eye: eye, target: target)
    }

    /// Ends a drag. Keeps `orbitYaw`/`orbitPitch` so the view stays where
    /// the user left it; only the per-drag baselines are cleared.
    func orbitEnded() {
        dragBaseYaw = nil
        dragBasePitch = nil
    }
}
