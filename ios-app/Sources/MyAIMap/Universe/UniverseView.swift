import SwiftUI
import RealityKit

/// Native RealityKit universe scene.
///
/// Phase 1 keeps the render path intentionally compact: one central core,
/// category anchors, and a curated first slice of real tools. Selecting a
/// category from SwiftUI opens it as a roomier "pocket world" so the iOS
/// prototype already demonstrates the core product behavior.
struct UniverseView: View {
    let selectedCategory: ToolCategoryId

    var body: some View {
        RealityView { content in
            let universe = Entity()
            content.add(universe)

            let camera = PerspectiveCamera()
            camera.position = cameraPosition(for: selectedCategory)
            camera.look(at: lookAtPosition(for: selectedCategory), from: camera.position, relativeTo: nil)
            universe.addChild(camera)

            universe.addChild(Self.makeToolNode(
                tool: UniverseSeed.tools.first { $0.id == "founder-os" },
                category: UniverseSeed.category(.core),
                position: .zero,
                selected: selectedCategory == .core
            ))

            for category in UniverseSeed.categories where category.id != .core {
                let center = UniverseLayout.categoryPosition(angleDegrees: category.angle)
                universe.addChild(Self.makeCategoryAnchor(category: category, position: center, selected: category.id == selectedCategory))

                let categoryTools = UniverseSeed.tools(in: category.id)
                for (index, tool) in categoryTools.enumerated() {
                    let isPocket = category.id == selectedCategory
                    let position = isPocket
                        ? UniverseLayout.pocketToolPosition(
                            angleDegrees: tool.angle,
                            orbit: tool.orbit,
                            categoryAngleDegrees: category.angle,
                            slotIndex: index,
                            slotCount: max(categoryTools.count, 1)
                        )
                        : UniverseLayout.toolPosition(
                            angleDegrees: tool.angle,
                            orbit: tool.orbit,
                            categoryAngleDegrees: category.angle
                        )
                    universe.addChild(Self.makeToolNode(
                        tool: tool,
                        category: category,
                        position: position,
                        selected: isPocket
                    ))
                }
            }

            let key = DirectionalLight()
            key.light.intensity = 1_200
            key.position = SIMD3<Float>(-4, 7, 10)
            universe.addChild(key)

            let fill = DirectionalLight()
            fill.light.intensity = 420
            fill.position = SIMD3<Float>(6, -2, 8)
            universe.addChild(fill)
        }
        .id(selectedCategory)
        .background(
            RadialGradient(
                colors: [
                    UniverseSeed.category(selectedCategory).color.swiftUIColor.opacity(0.18),
                    Color(red: 0.01, green: 0.015, blue: 0.035),
                    .black
                ],
                center: .center,
                startRadius: 80,
                endRadius: 560
            )
        )
    }

    private func lookAtPosition(for category: ToolCategoryId) -> SIMD3<Float> {
        guard category != .core else { return .zero }
        return UniverseLayout.categoryPosition(angleDegrees: UniverseSeed.category(category).angle)
    }

    private func cameraPosition(for category: ToolCategoryId) -> SIMD3<Float> {
        let target = lookAtPosition(for: category)
        if category == .core {
            return SIMD3<Float>(0, 5.4, 20.5)
        }
        return SIMD3<Float>(target.x, target.y + 5.2, target.z + 15.4)
    }

    private static func makeCategoryAnchor(category: ToolCategory, position: SIMD3<Float>, selected: Bool) -> ModelEntity {
        let radius: Float = selected ? 0.74 : 0.48
        let anchor = ModelEntity(
            mesh: .generateSphere(radius: radius),
            materials: [SimpleMaterial(color: category.color.uiColor.withAlphaComponent(selected ? 0.92 : 0.62), isMetallic: false)]
        )
        anchor.position = position
        return anchor
    }

    private static func makeToolNode(
        tool: Tool?,
        category: ToolCategory,
        position: SIMD3<Float>,
        selected: Bool
    ) -> ModelEntity {
        let orbitRadius = Float(tool?.orbit.rawValue ?? 0)
        let radius: Float = selected ? 0.34 + orbitRadius * 0.045 : 0.24 + orbitRadius * 0.025
        let node = ModelEntity(
            mesh: .generateSphere(radius: radius),
            materials: [SimpleMaterial(color: category.color.uiColor.withAlphaComponent(selected ? 0.96 : 0.74), isMetallic: false)]
        )
        node.position = position
        return node
    }
}

#Preview {
    UniverseView(selectedCategory: .design)
}
