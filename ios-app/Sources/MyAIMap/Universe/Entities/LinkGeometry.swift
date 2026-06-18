import Foundation
import simd

/// Pure geometry math for structural connection lines (backlog 18,
/// review Pillar-1). A line is rendered as a unit box stretched along
/// one axis to span two points; this enum computes the transform that
/// places, sizes, and orients that box. Foundation + simd only — no
/// RealityKit — so it's unit-testable from the `MyAIMapTests` target.
///
/// Convention: the box's LENGTH axis is +Y. A unit box is 1×1×1, so a
/// scale of (thickness, length, thickness) makes a thin bar of the
/// right length, and the rotation aligns that local +Y with the
/// `from → to` direction.
enum LinkGeometry {
    /// Local axis the box is stretched along (its "length"). The
    /// rotation in `transform` maps this onto the normalized
    /// `from → to` direction.
    static let lengthAxis = SIMD3<Float>(0, 1, 0)

    /// Transform for a unit box spanning `from` to `to`.
    ///
    /// - `position`: the segment midpoint.
    /// - `scale`: `lengthAxis` component == distance(from, to); the two
    ///   perpendicular components == `thickness`.
    /// - `rotation`: rotates local +Y onto normalized(to - from).
    ///
    /// A degenerate `from == to` (zero-length) is guarded: scale's length
    /// component is 0 and rotation is identity — no NaNs, no crash.
    static func transform(
        from: SIMD3<Float>,
        to: SIMD3<Float>,
        thickness: Float
    ) -> (position: SIMD3<Float>, scale: SIMD3<Float>, rotation: simd_quatf) {
        let delta = to - from
        let length = simd_length(delta)
        let position = (from + to) * 0.5
        let scale = SIMD3<Float>(thickness, length, thickness)

        guard length > 1e-6 else {
            // Zero-length: direction is undefined. Identity rotation,
            // zero length scale — the box collapses to nothing.
            return (position, scale, simd_quatf(ix: 0, iy: 0, iz: 0, r: 1))
        }

        let rotation = simd_quatf(from: lengthAxis, to: delta / length)
        return (position, scale, rotation)
    }
}
