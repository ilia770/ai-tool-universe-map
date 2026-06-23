import Foundation

/// The single inline reveal in 3D: a glass card for the focused tool-planet.
/// Shown only when a tool is selected in spatial mode (principle 4 —
/// only the selected planet reveals detail). Overview/sun-focus stay bare.
enum SpatialReveal {
    static func showsToolCard(renderMode: UniverseRenderMode, mode: UniverseMode) -> Bool {
        guard renderMode == .spatial3D else { return false }
        if case .toolSelected = mode { return true }
        return false
    }
}
