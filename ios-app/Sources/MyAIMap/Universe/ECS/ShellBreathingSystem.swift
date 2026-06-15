import Foundation
import RealityKit

/// Marks the open pocket-shell root so `ShellBreathingSystem` animates it.
/// Only attached when reduce-motion is off — its mere presence means
/// "breathe me", so the system never needs to re-check the setting.
struct ShellBreathingComponent: Component {}

/// Per-frame pocket-shell wobble + group yaw sway (backlog 22), restoring the
/// motion dropped in slice 3. All curve math lives in the pure `ShellBreathing`
/// enum; this system only advances a clock and writes the transform on every
/// tagged entity. Unlocked by the persistent scene (backlog 16): the shell
/// entity survives across selection changes, so a per-frame system can own its
/// transform without fighting a rebuild.
final class ShellBreathingSystem: System {
    private static let query = EntityQuery(where: .has(ShellBreathingComponent.self))
    private static let yawAxis = SIMD3<Float>(0, 1, 0)

    private var elapsedTime: TimeInterval = 0

    init(scene: RealityKit.Scene) {}

    func update(context: SceneUpdateContext) {
        elapsedTime += context.deltaTime
        let scale = ShellBreathing.scale(time: elapsedTime, reduceMotion: false)
        let yaw = ShellBreathing.yaw(time: elapsedTime, reduceMotion: false)
        let rotation = simd_quatf(angle: yaw, axis: Self.yawAxis)
        for entity in context.entities(matching: Self.query, updatingSystemWhen: .rendering) {
            entity.scale = SIMD3<Float>(repeating: scale)
            entity.orientation = rotation
        }
    }
}
