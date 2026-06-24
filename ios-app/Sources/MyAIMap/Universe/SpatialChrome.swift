import Foundation

/// Chrome that only belongs to the 2D graph. In 3D the suns ARE the
/// navigation, so the category rail, planet info card, and bottom category
/// rail are hidden (principle 6: near-zero noise).
enum SpatialChrome {
    static func showsMapChrome(
        renderMode: UniverseRenderMode,
        mode: UniverseMode,
        isUniverseEmpty: Bool
    ) -> Bool {
        guard renderMode == .graph2D else { return false }
        return !mode.isDetailOpen && !mode.isChatOpen && !isUniverseEmpty
    }
}
