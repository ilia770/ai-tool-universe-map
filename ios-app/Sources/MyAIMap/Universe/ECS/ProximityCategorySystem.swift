import Foundation
import RealityKit

/// RealityKit System polling camera↔anchor distance each frame
/// (PHASE_2_PLAN step 4). Thin shell: throttle, cooldown, and
/// hysteresis all live in the pure `ProximityWatcherCore`.
final class ProximityCategorySystem: System {
    private static let query = EntityQuery(where: .has(UniverseStateComponent.self))

    private var core = ProximityWatcherCore()
    private var elapsedTime: TimeInterval = 0

    init(scene: RealityKit.Scene) {}

    func update(context: SceneUpdateContext) {
        elapsedTime += context.deltaTime
        for entity in context.entities(matching: Self.query, updatingSystemWhen: .rendering) {
            guard let state = entity.components[UniverseStateComponent.self] else { continue }
            let event = core.tick(
                now: elapsedTime,
                cameraPosition: state.camera.position(relativeTo: nil),
                activeCategory: state.activeCategory,
                anchors: state.anchors
            )
            if let event {
                state.onProximityEvent(event)
            }
        }
    }
}
