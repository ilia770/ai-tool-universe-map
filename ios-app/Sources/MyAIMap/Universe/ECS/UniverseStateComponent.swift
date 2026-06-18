import Foundation
import RealityKit

/// Per-scene state for `ProximityCategorySystem`: which pocket is open,
/// the category anchor positions, the camera to measure from, and where
/// to send enter/exit events. `UniverseView` attaches it to the universe
/// root entity. The scene is rebuilt on every category change
/// (`.id(selectedCategory)` in UniverseView), so `activeCategory` is
/// fixed for the lifetime of each component instance.
struct UniverseStateComponent: Component {
    let activeCategory: ToolCategoryId
    let anchors: [ProximityWatcherCore.Anchor]
    let camera: Entity
    let onProximityEvent: @MainActor (ProximityWatcherCore.Event) -> Void
}
