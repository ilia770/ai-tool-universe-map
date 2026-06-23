import simd

/// While free-orbiting a focused sun, the rig's yaw rotates around the galaxy.
/// `focus(on:)` sets yaw to a sun's bearing `atan2(x, z+0.001) + 0.24`, so when
/// yaw drifts within `thresholdRadians` of a *different* sun's bearing, that
/// neighbor takes focus (soft snap). Pure: returns the sun to snap to, or nil.
enum NeighborSnap {
    struct Sun: Equatable {
        let id: ToolCategoryId
        let position: SIMD3<Float>
    }

    static func snapTarget(
        currentFocus: ToolCategoryId,
        yaw: Float,
        suns: [Sun],
        thresholdRadians: Float
    ) -> ToolCategoryId? {
        func bearing(_ p: SIMD3<Float>) -> Float { atan2(p.x, p.z + 0.001) + 0.24 }
        func angleDelta(_ a: Float, _ b: Float) -> Float {
            let twoPi = Float.pi * 2
            let d = abs(a - b).truncatingRemainder(dividingBy: twoPi)
            return min(d, twoPi - d)
        }
        var best: (id: ToolCategoryId, delta: Float)?
        for sun in suns where sun.id != currentFocus {
            let delta = angleDelta(yaw, bearing(sun.position))
            if delta < thresholdRadians, delta < (best?.delta ?? .greatestFiniteMagnitude) {
                best = (sun.id, delta)
            }
        }
        return best?.id
    }
}
