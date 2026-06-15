import Foundation
import RealityKit

/// Marks a billboarded tool-label root so `ToolLabelFadeSystem` updates its
/// opacity from the camera distance each frame.
struct ToolLabelComponent: Component {}

/// Per-frame distance fade for pocketed tool labels (backlog 26). Reads the
/// camera off the scene's `UniverseStateComponent` (same source the proximity
/// system uses), measures each label's distance, and writes the opacity from
/// the pure `ToolLabelFade` curve — so labels are crisp inside an open pocket
/// and fade to nothing as the camera pulls back to overview.
final class ToolLabelFadeSystem: System {
    private static let labelQuery = EntityQuery(where: .has(ToolLabelComponent.self))
    private static let stateQuery = EntityQuery(where: .has(UniverseStateComponent.self))

    init(scene: RealityKit.Scene) {}

    func update(context: SceneUpdateContext) {
        var cameraPosition: SIMD3<Float>?
        for entity in context.entities(matching: Self.stateQuery, updatingSystemWhen: .rendering) {
            cameraPosition = entity.components[UniverseStateComponent.self]?.camera.position(relativeTo: nil)
            break
        }
        guard let cameraPosition else { return }

        for label in context.entities(matching: Self.labelQuery, updatingSystemWhen: .rendering) {
            let distance = simd_distance(label.position(relativeTo: nil), cameraPosition)
            let opacity = ToolLabelFade.opacity(distance: distance)
            label.components.set(OpacityComponent(opacity: opacity))
        }
    }
}
