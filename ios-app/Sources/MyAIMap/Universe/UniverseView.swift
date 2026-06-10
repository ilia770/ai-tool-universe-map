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
    let selectedToolId: String
    let onProximityEvent: @MainActor (ProximityWatcherCore.Event) -> Void

    @State private var cameraController = CameraController()

    private var viewMode: ViewMode {
        selectedCategory == .core ? .overview : .pocket
    }

    var body: some View {
        RealityView { content in
            // Idempotent; must run before the scene starts updating.
            UniverseStateComponent.registerComponent()
            ProximityCategorySystem.registerSystem()

            let universe = Entity()
            content.add(universe)

            let camera = PerspectiveCamera()
            universe.addChild(camera)
            cameraController.attach(camera, mode: viewMode, target: lookAtPosition(for: selectedCategory))

            universe.addChild(Self.makeToolNode(
                tool: UniverseSeed.tools.first { $0.id == "founder-os" },
                category: UniverseSeed.category(.core),
                position: .zero,
                selected: selectedCategory == .core
            ))

            var anchors: [ProximityWatcherCore.Anchor] = []
            for category in UniverseSeed.categories where category.id != .core {
                let center = UniverseLayout.categoryPosition(angleDegrees: category.angle)
                anchors.append(ProximityWatcherCore.Anchor(id: category.id, position: center))
                universe.addChild(Self.makeCategoryAnchor(category: category, position: center, selected: category.id == selectedCategory))

                let categoryTools = UniverseSeed.tools(in: category.id)
                for (index, tool) in categoryTools.enumerated() {
                    let isPocket = category.id == selectedCategory
                    let isSelectedTool = tool.id == selectedToolId
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
                        selected: isSelectedTool,
                        pocketed: isPocket
                    ))
                }
            }

            universe.components.set(UniverseStateComponent(
                activeCategory: selectedCategory,
                anchors: anchors,
                camera: camera,
                onProximityEvent: onProximityEvent
            ))

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
        .gesture(
            MagnifyGesture()
                .onChanged { value in
                    cameraController.pinchChanged(magnification: Float(value.magnification))
                }
                .onEnded { _ in
                    cameraController.pinchEnded()
                }
        )
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
        selected: Bool,
        pocketed: Bool = false
    ) -> ModelEntity {
        let orbitRadius = Float(tool?.orbit.rawValue ?? 0)
        let radius: Float = selected
            ? 0.46 + orbitRadius * 0.055
            : pocketed
                ? 0.32 + orbitRadius * 0.04
                : 0.24 + orbitRadius * 0.025
        let alpha: CGFloat = selected ? 1.0 : pocketed ? 0.88 : 0.64
        let node = ModelEntity(
            mesh: .generateSphere(radius: radius),
            materials: [SimpleMaterial(color: category.color.uiColor.withAlphaComponent(alpha), isMetallic: false)]
        )
        node.position = position
        return node
    }
}

#Preview {
    UniverseView(selectedCategory: .design, selectedToolId: "figma", onProximityEvent: { _ in })
}
