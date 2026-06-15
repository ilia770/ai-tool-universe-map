import Foundation

/// Distance-fade curve for billboarded tool labels (backlog 26). Pocketed
/// tools get a floating name label; to keep the open pocket legible without
/// cluttering the overview, each label fades out as the camera pulls away —
/// fully readable up close, gone by the time you're back at overview range.
///
/// Pure (Foundation-only) so the curve is unit-tested; `ToolLabelFadeSystem`
/// samples it per frame against the camera distance.
enum ToolLabelFade {

    /// At or nearer than this (world units) the label is fully opaque.
    static let nearDistance: Float = 6
    /// At or beyond this the label is fully gone. Chosen so labels vanish as
    /// the camera leaves a pocket but well inside the camera's max range (46).
    static let farDistance: Float = 18

    /// Label opacity for a camera `distance`, linearly ramped from 1 at
    /// `nearDistance` to 0 at `farDistance`, clamped to [0, 1].
    static func opacity(distance: Float) -> Float {
        if distance <= nearDistance { return 1 }
        if distance >= farDistance { return 0 }
        return (farDistance - distance) / (farDistance - nearDistance)
    }
}
