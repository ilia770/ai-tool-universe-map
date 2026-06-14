import Foundation
import RealityKit
import UIKit

/// Ambient cosmic backdrop — a static field of tiny stars on a large sphere
/// shell enclosing the whole scene (radius well beyond the camera's
/// maxDistance), so the universe sits in a star field instead of a flat
/// void. Native port of the web `StarField.tsx` in spirit: two brightness
/// tiers of small, dim white/blue points, no per-frame animation in this
/// slice (ambient drift is a later polish).
///
/// RealityKit has no point-cloud primitive, so each star is a tiny sphere
/// ModelEntity placed at a `StarFieldGeometry` position. To keep this cheap
/// the per-tier MeshResource and UnlitMaterial are each built ONCE and
/// shared across every child in that tier — only the lightweight Entity
/// wrappers and transforms differ. Stars carry no InputTargetComponent or
/// collision, so they can never steal a tap, and at shell distance they
/// render as faint specks in the background.
@MainActor
enum StarFieldEntity {

    /// Dim white-blue star tint (web stars are white lerped toward blue).
    private static let starColor = UIColor(red: 0.82, green: 0.90, blue: 1.0, alpha: 1)

    static func make() -> Entity {
        let root = Entity()
        root.name = "starfield"

        let positions = StarFieldGeometry.positions()
        let brightCount = Int(Float(positions.count) * StarFieldGeometry.brightTierFraction)

        // One shared mesh + material per tier (see type doc — the whole
        // point of the sphere-instancing approach is reuse).
        let brightMesh = MeshResource.generateSphere(radius: StarFieldGeometry.brightStarRadius)
        let dimMesh = MeshResource.generateSphere(radius: StarFieldGeometry.dimStarRadius)
        let brightMaterial = material(opacity: StarFieldGeometry.brightStarOpacity)
        let dimMaterial = material(opacity: StarFieldGeometry.dimStarOpacity)

        for (index, position) in positions.enumerated() {
            let isBright = index < brightCount
            let star = ModelEntity(
                mesh: isBright ? brightMesh : dimMesh,
                materials: [isBright ? brightMaterial : dimMaterial]
            )
            star.position = position
            root.addChild(star)
        }

        return root
    }

    /// Unlit so the stars glow at a fixed brightness independent of the
    /// scene's key/fill lighting rig.
    private static func material(opacity: Float) -> UnlitMaterial {
        var material = UnlitMaterial(color: starColor)
        material.blending = .transparent(opacity: .init(floatLiteral: opacity))
        return material
    }
}
