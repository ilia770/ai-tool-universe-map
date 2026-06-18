import Foundation
import Observation
import RealityKit
import simd

/// Cinematic camera rig for the native RealityKit universe.
///
/// The camera keeps a premium 3/4 perspective instead of a top-down map.
/// `pan(delta:)`, `zoom(delta:)`, and `focus(on:)` are intentionally small
/// imperative hooks so SwiftUI gestures can stay thin.
@MainActor
@Observable
final class CameraRigController {
    nonisolated static let minDistance: Float = 6.2
    nonisolated static let maxDistance: Float = 28
    nonisolated static let overviewDistance: Float = 21.4
    nonisolated static let transitionDuration: TimeInterval = 1.05
    nonisolated static let toolTransitionDuration: TimeInterval = 0.68
    nonisolated static let detailTransitionDuration: TimeInterval = 0.32

    private(set) var yaw: Float = -0.24
    private(set) var pitch: Float = 0.28
    private(set) var distance: Float = overviewDistance
    private(set) var target: SIMD3<Float> = .zero
    private(set) var isTransitioning = false

    /// True while a drag/pinch is actively manipulating the camera. The overlay
    /// label layers gate on this to avoid re-projecting every label on every
    /// gesture frame (perf), then refresh once the gesture ends.
    private(set) var isInteracting = false

    /// When set (Reduce Motion, or `-uitestStatic`), cinematic fly-to is
    /// collapsed to an instant cut: focus/overview snap rather than animate.
    /// Accessibility + lets XCUITest reach quiescence (camera transition Tasks
    /// otherwise keep the app busy like the ambient scene animations did).
    var prefersInstant = false

    @ObservationIgnored private(set) weak var camera: PerspectiveCamera?
    @ObservationIgnored private var activeGestureCount = 0
    @ObservationIgnored private var zoomBaseDistance: Float?
    @ObservationIgnored private var transitionTask: Task<Void, Never>?
    @ObservationIgnored private var transitionGeneration = 0

    nonisolated init() {}

    func attach(_ camera: PerspectiveCamera) {
        self.camera = camera
        camera.camera.fieldOfViewInDegrees = 44
        applyCamera(animated: false)
    }

    func overview(animated: Bool = true) {
        target = .zero
        distance = Self.overviewDistance
        pitch = 0.26
        applyCamera(animated: animated, duration: 1.12)
    }

    func focus(category planet: PlanetData, animated: Bool = true) {
        focus(on: planet, animated: animated)
    }

    func focus(
        tool: Tool,
        around planet: PlanetData,
        index: Int,
        count: Int,
        animated: Bool = true
    ) {
        focus(on: tool, around: planet, index: index, count: count, animated: animated)
    }

    func enterDetail(
        tool: Tool,
        around planet: PlanetData,
        index: Int,
        count: Int,
        animated: Bool = true
    ) {
        enterDetail(on: tool, around: planet, index: index, count: count, animated: animated)
    }

    func enterChat(animated: Bool = true) {
        enterChat(focusedOn: nil, animated: animated)
    }

    func reset() {
        yaw = -0.24
        pitch = 0.28
        overview(animated: true)
    }

    func focus(on planet: PlanetData, animated: Bool = true) {
        target = planet.position3D
        distance = max(Self.minDistance, min(Self.maxDistance, planet.radius * 6.8 + 5.0))
        pitch = 0.24
        // Bias the orbit so a focused side planet still shows curvature and
        // some surrounding space instead of becoming a flat centered coin.
        yaw = atan2(planet.position3D.x, planet.position3D.z + 0.001) + 0.24
        applyCamera(animated: animated, duration: Self.transitionDuration)
    }

    func focus(
        on tool: Tool,
        around planet: PlanetData,
        index: Int,
        count: Int,
        animated: Bool = true
    ) {
        let toolPosition = UniverseSpatialLayout.satelliteWorldPosition(
            for: tool,
            in: planet,
            index: index,
            count: count
        )
        target = planet.position3D + (toolPosition - planet.position3D) * 0.74
        distance = max(Self.minDistance, min(Self.maxDistance, planet.radius * 6.0 + 4.6))
        pitch = 0.20
        yaw = atan2(toolPosition.x, toolPosition.z + 0.001) + 0.18
        applyCamera(animated: animated, duration: Self.toolTransitionDuration)
    }

    func enterDetail(
        on tool: Tool,
        around planet: PlanetData,
        index: Int,
        count: Int,
        animated: Bool = true
    ) {
        let toolPosition = UniverseSpatialLayout.satelliteWorldPosition(
            for: tool,
            in: planet,
            index: index,
            count: count
        )
        target = planet.position3D + (toolPosition - planet.position3D) * 0.54
        distance = max(Self.minDistance + 1.2, min(Self.maxDistance, planet.radius * 7.8 + 5.8))
        pitch = 0.18
        yaw = atan2(toolPosition.x, toolPosition.z + 0.001) + 0.22
        applyCamera(animated: animated, duration: Self.detailTransitionDuration)
    }

    func enterChat(focusedOn planet: PlanetData?, animated: Bool = true) {
        target = planet?.position3D ?? .zero
        distance = max(Self.minDistance + 2, min(Self.maxDistance, (planet?.radius ?? 1.2) * 8.2 + 7.0))
        pitch = 0.22
        if let planet {
            yaw = atan2(planet.position3D.x, planet.position3D.z + 0.001) + 0.28
        }
        applyCamera(animated: animated, duration: Self.detailTransitionDuration)
    }

    func returnToOverview(animated: Bool = true) {
        overview(animated: animated)
    }

    /// Mark the start of a camera-manipulating gesture (drag or pinch). Safe to
    /// nest: a drag and a pinch can overlap and the flag stays set until both
    /// gestures end.
    func beginInteraction() {
        activeGestureCount += 1
        if !isInteracting { isInteracting = true }
    }

    /// Mark the end of a camera-manipulating gesture. The flag clears only once
    /// all in-flight gestures have ended.
    func endInteraction() {
        guard activeGestureCount > 0 else { return }
        activeGestureCount -= 1
        if activeGestureCount == 0 { isInteracting = false }
    }

    func pan(delta: CGSize) {
        guard !isTransitioning else { return }
        yaw -= Float(delta.width) * 0.0062
        pitch = Self.clamp(pitch + Float(delta.height) * 0.0038, min: -0.16, max: 0.72)
        applyCamera(animated: false)
    }

    func finishPan(predictedDelta: CGSize) {
        guard !isTransitioning else { return }
        yaw -= Float(predictedDelta.width) * 0.0016
        pitch = Self.clamp(pitch + Float(predictedDelta.height) * 0.001, min: -0.16, max: 0.72)
        applyCamera(animated: true, duration: 0.42)
    }

    func zoom(delta: Float) {
        distance = Self.clamp(distance + delta, min: Self.minDistance, max: Self.maxDistance)
        applyCamera(animated: true, duration: 0.24)
    }

    func zoom(magnification: Float) {
        guard !isTransitioning else { return }
        if zoomBaseDistance == nil {
            zoomBaseDistance = distance
            camera?.stopAllAnimations()
        }
        let base = zoomBaseDistance ?? distance
        guard magnification > 0.001 else { return }
        distance = Self.clamp(base / magnification, min: Self.minDistance, max: Self.maxDistance)
        applyCamera(animated: false)
    }

    func endZoom() {
        zoomBaseDistance = nil
    }

    func projection(for worldPosition: SIMD3<Float>, in size: CGSize) -> UniverseLabelProjection {
        let relative = worldPosition - target
        let yawCos = cos(-yaw)
        let yawSin = sin(-yaw)
        let yawed = SIMD3<Float>(
            relative.x * yawCos - relative.z * yawSin,
            relative.y,
            relative.x * yawSin + relative.z * yawCos
        )
        let pitchCos = cos(-pitch)
        let pitchSin = sin(-pitch)
        let cameraSpace = SIMD3<Float>(
            yawed.x,
            yawed.y * pitchCos - yawed.z * pitchSin,
            yawed.y * pitchSin + yawed.z * pitchCos
        )

        let depth = max(1.8, distance + cameraSpace.z)
        let focal = min(size.width, size.height) * 0.86
        let perspective = CGFloat(focal / CGFloat(depth))
        let point = CGPoint(
            x: size.width * 0.5 + CGFloat(cameraSpace.x) * perspective,
            y: size.height * 0.40 - CGFloat(cameraSpace.y) * perspective
        )
        let normalizedDepth = Self.clamp((Self.maxDistance - depth) / Self.maxDistance, min: 0, max: 1)
        return UniverseLabelProjection(
            point: point,
            scale: CGFloat(0.68 + normalizedDepth * 0.42),
            opacity: Double(0.22 + normalizedDepth * 0.78),
            isVisible: point.x > -120 && point.x < size.width + 120 && point.y > -80 && point.y < size.height + 80
        )
    }

    private func applyCamera(animated: Bool, duration: TimeInterval = 0.8) {
        guard let camera else { return }
        let animated = animated && !prefersInstant
        let eye = eyePosition()
        var transform = camera.transform
        transform.translation = eye
        transform.rotation = Self.lookRotation(eye: eye, target: target)

        transitionTask?.cancel()
        transitionGeneration += 1
        let generation = transitionGeneration
        camera.stopAllAnimations()
        if animated {
            isTransitioning = true
            let landingTransform = transform
            let currentTransform = camera.transform
            let currentOffset = currentTransform.translation - target
            let retreatDirection = simd_length(currentOffset) > 0.0001
                ? simd_normalize(currentOffset)
                : simd_normalize(landingTransform.translation - target)
            var pullbackTransform = currentTransform
            pullbackTransform.translation += retreatDirection * 0.72
            pullbackTransform.rotation = Self.lookRotation(eye: pullbackTransform.translation, target: target)

            camera.move(to: pullbackTransform, relativeTo: camera.parent, duration: 0.15, timingFunction: .easeOut)
            transitionTask = Task { @MainActor [weak self, weak camera, generation] in
                try? await Task.sleep(nanoseconds: 150_000_000)
                guard !Task.isCancelled, self?.transitionGeneration == generation else { return }
                camera?.move(
                    to: landingTransform,
                    relativeTo: camera?.parent,
                    duration: max(0.1, duration - 0.15),
                    timingFunction: .easeInOut
                )
                let nanoseconds = UInt64((duration + 0.05) * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanoseconds)
                guard !Task.isCancelled, self?.transitionGeneration == generation else { return }
                self?.isTransitioning = false
            }
        } else {
            camera.transform = transform
            isTransitioning = false
        }
    }

    private func eyePosition() -> SIMD3<Float> {
        let horizontal = distance * cos(pitch)
        return target + SIMD3<Float>(
            sin(yaw) * horizontal,
            max(3.2, distance * sin(pitch) + 1.3),
            cos(yaw) * horizontal
        )
    }

    nonisolated static func lookRotation(eye: SIMD3<Float>, target: SIMD3<Float>) -> simd_quatf {
        let offset = eye - target
        guard simd_length(offset) > 0.0001 else {
            return simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))
        }
        let back = simd_normalize(offset)
        let worldUp = SIMD3<Float>(0, 1, 0)
        var right = simd_cross(worldUp, back)
        if simd_length(right) < 0.0001 {
            right = SIMD3<Float>(1, 0, 0)
        } else {
            right = simd_normalize(right)
        }
        let up = simd_cross(back, right)
        return simd_quatf(simd_float3x3(columns: (right, up, back)))
    }

    nonisolated static func clamp(_ value: Float, min lower: Float, max upper: Float) -> Float {
        Swift.min(Swift.max(value, lower), upper)
    }
}
