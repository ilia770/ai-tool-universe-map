import Foundation
import RealityKit

/// Per-scene state for `ProximityCategorySystem`: which pocket is open,
/// the category anchor positions, the camera to measure from, and where
/// to send enter/exit events. `UniverseView` attaches it to the universe
/// root entity. The scene persists across category changes (backlog task
/// 16) — `UniverseView`'s update closure replaces this component in place
/// when the selection moves, comparing `activeCategory` / `activeToolId`
/// against the incoming SwiftUI state to detect what changed. The system
/// instance (and its `ProximityWatcherCore` cooldown/arming state)
/// survives because the scene is never torn down.
struct UniverseStateComponent: Component {
    let activeCategory: ToolCategoryId
    /// Tracked here purely so the update closure can diff tool selection;
    /// the proximity system ignores it.
    let activeToolId: String
    let anchors: [ProximityWatcherCore.Anchor]
    let camera: Entity
    let onProximityEvent: @MainActor (ProximityWatcherCore.Event) -> Void
}
