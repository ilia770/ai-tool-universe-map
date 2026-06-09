import SwiftUI
import RealityKit

/// Phase 0 placeholder scene.
///
/// Renders the central `Founder OS` core entity as a glowing sphere and a
/// handful of category anchor placeholders on a single ring, so the
/// project builds + launches end-to-end before Phase 1 ports the real
/// data + Fibonacci-sphere pocket layout.
///
/// Layout math here intentionally mirrors the web app's
/// `src/components/AIToolUniverse3D/layout.ts` so the eventual port
/// stays predictable.
struct UniverseView: View {
    var body: some View {
        RealityView { content in
            // Root pivot — every later entity is a child of this so we can
            // animate the whole universe with a single transform.
            let universe = Entity()
            content.add(universe)

            // Camera anchor — Phase 0 fixed camera; Phase 2 swaps for a
            // PerspectiveCamera + ProximityCategoryWatcher port.
            let camera = PerspectiveCamera()
            camera.position = SIMD3<Float>(0, 5.4, 20.5)
            camera.look(at: .zero, from: camera.position, relativeTo: nil)
            universe.addChild(camera)

            // Founder OS core node.
            universe.addChild(Self.makeCore())

            // Category anchors at the web app's `CATEGORY_RADIUS_X` / `Z`.
            for anchor in Self.placeholderAnchors() {
                universe.addChild(anchor)
            }

            // Soft ambient lighting so the unlit placeholder spheres read
            // on a near-black background without going full silhouette.
            let ambient = DirectionalLight()
            ambient.light.intensity = 800
            ambient.position = SIMD3<Float>(0, 6, 12)
            universe.addChild(ambient)
        }
        .background(Color.black)
    }

    private static let categoryRadiusX: Float = 4.55
    private static let categoryRadiusZ: Float = 3.45

    /// The eight non-core category anchors at evenly spaced angles,
    /// matching the web app's `categoryPosition(angle)` math.
    private static func placeholderAnchors() -> [Entity] {
        let categoryAngles: [Float] = [0, 45, 90, 135, 180, 225, 270, 315]
        return categoryAngles.map { angleDegrees in
            let radians = angleDegrees * .pi / 180
            let entity = ModelEntity(
                mesh: .generateSphere(radius: 0.55),
                materials: [SimpleMaterial(color: .systemTeal, isMetallic: false)]
            )
            entity.position = SIMD3<Float>(
                cos(radians) * categoryRadiusX,
                sin(radians * 1.7) * 1.35,
                sin(radians) * categoryRadiusZ
            )
            return entity
        }
    }

    /// Founder OS core — the central node every category ring orbits.
    private static func makeCore() -> ModelEntity {
        let core = ModelEntity(
            mesh: .generateSphere(radius: 0.45),
            materials: [SimpleMaterial(color: .white, isMetallic: false)]
        )
        return core
    }
}

#Preview {
    UniverseView()
}
