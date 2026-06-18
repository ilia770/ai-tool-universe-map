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
    let tools: [Tool]
    let visualizationStyle: VisualizationStyle
    let onToolSelect: @MainActor (String) -> Void
    let onProximityEvent: @MainActor (ProximityWatcherCore.Event) -> Void

    @State private var cameraController = CameraController()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                tool: tools.first { $0.id == "founder-os" },
                category: UniverseSeed.category(.core),
                position: .zero,
                selected: selectedCategory == .core,
                visualizationStyle: visualizationStyle
            ))

            var anchors: [ProximityWatcherCore.Anchor] = []
            for category in UniverseSeed.categories where category.id != .core {
                let center = UniverseLayout.categoryPosition(angleDegrees: category.angle)
                anchors.append(ProximityWatcherCore.Anchor(id: category.id, position: center))
                universe.addChild(Self.makeCategoryAnchor(
                    category: category,
                    position: center,
                    selected: category.id == selectedCategory,
                    visualizationStyle: visualizationStyle
                ))
                if category.id == selectedCategory {
                    universe.addChild(PocketShellEntity.make(category: category, position: center, reduceMotion: reduceMotion))
                }

                let categoryTools = tools.filter { $0.category == category.id }
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
                        pocketed: isPocket,
                        visualizationStyle: visualizationStyle
                    ))
                }
            }

            universe.components.set(UniverseStateComponent(
                activeCategory: selectedCategory,
                anchors: anchors,
                camera: camera,
                onProximityEvent: onProximityEvent
            ))

            // PBR needs more light than SimpleMaterial did. Key is a soft
            // neutral from upper-left; fill is dimmer and slightly cool so
            // shadowed hemispheres read as depth, not dead black. Both are
            // aimed at the origin — DirectionalLight direction comes from
            // orientation, not position.
            let key = DirectionalLight()
            key.light.intensity = 2_600
            key.position = SIMD3<Float>(-4, 7, 10)
            key.look(at: .zero, from: key.position, relativeTo: nil)
            universe.addChild(key)

            let fill = DirectionalLight()
            fill.light.intensity = 750
            fill.light.color = UIColor(red: 0.74, green: 0.80, blue: 1.0, alpha: 1)
            fill.position = SIMD3<Float>(6, -2, 8)
            fill.look(at: .zero, from: fill.position, relativeTo: nil)
            universe.addChild(fill)
        }
        .id(sceneIdentity)
        .gesture(
            SpatialTapGesture()
                .targetedToAnyEntity()
                .onEnded { value in
                    handleTap(on: value.entity)
                }
        )
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
                    UniverseSeed.category(selectedCategory).color.swiftUIColor.opacity(visualizationStyle.backgroundGlow),
                    Color(red: 0.01, green: 0.015, blue: 0.035),
                    .black
                ],
                center: .center,
                startRadius: 80,
                endRadius: 560
            )
        )
    }

    private var sceneIdentity: String {
        [
            selectedCategory.rawValue,
            selectedToolId,
            visualizationStyle.rawValue,
            tools.map(\.id).joined(separator: ","),
        ].joined(separator: "|")
    }

    /// Tap routing mirrors the interim 2D map (#41): tool nodes select the
    /// tool, category anchors open their pocket via the same event path the
    /// proximity system uses, so haptics/state stay in one place upstream.
    private func handleTap(on entity: Entity) {
        if entity.name.hasPrefix("tool:") {
            onToolSelect(String(entity.name.dropFirst("tool:".count)))
        } else if entity.name.hasPrefix("cat:"),
                  let categoryId = ToolCategoryId(rawValue: String(entity.name.dropFirst("cat:".count))) {
            onProximityEvent(.enter(categoryId))
        }
    }

    private func lookAtPosition(for category: ToolCategoryId) -> SIMD3<Float> {
        guard category != .core else { return .zero }
        return UniverseLayout.categoryPosition(angleDegrees: UniverseSeed.category(category).angle)
    }

    private static func makeTappable(_ entity: ModelEntity, name: String, radius: Float) {
        entity.name = name
        entity.components.set(InputTargetComponent())
        entity.components.set(CollisionComponent(shapes: [.generateSphere(radius: radius)]))
    }

    /// Frosted translucent category sphere: matte PBR glass tinted by the
    /// category hue, with a faint emissive lift so the shell reads as a
    /// lit volume instead of a flat colored ball.
    private static func makeCategoryAnchor(
        category: ToolCategory,
        position: SIMD3<Float>,
        selected: Bool,
        visualizationStyle: VisualizationStyle
    ) -> ModelEntity {
        let radius: Float = (selected ? 0.74 : 0.48) * visualizationStyle.categoryScale
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: darkened(category.color.uiColor, by: 0.45))
        material.roughness = .init(floatLiteral: 0.6)
        material.metallic = .init(floatLiteral: 0.0)
        material.blending = .transparent(opacity: .init(floatLiteral: selected ? 0.9 : 0.5))
        material.emissiveColor = .init(color: category.color.uiColor)
        material.emissiveIntensity = (selected ? 0.65 : 0.28) * visualizationStyle.glowBoost
        let anchor = ModelEntity(
            mesh: .generateSphere(radius: radius),
            materials: [material]
        )
        anchor.position = position
        // Oversized hit shape — anchors are small targets at overview distance.
        makeTappable(anchor, name: "cat:\(category.id.rawValue)", radius: max(radius * 1.8, 1.1))
        return anchor
    }

    private static func makeToolNode(
        tool: Tool?,
        category: ToolCategory,
        position: SIMD3<Float>,
        selected: Bool,
        pocketed: Bool = false,
        visualizationStyle: VisualizationStyle = .orbitalGlass
    ) -> ModelEntity {
        let orbitRadius = Float(tool?.orbit.rawValue ?? 0)
        let baseRadius: Float = selected
            ? 0.46 + orbitRadius * 0.055
            : pocketed
                ? 0.32 + orbitRadius * 0.04
                : 0.24 + orbitRadius * 0.025
        let radius = baseRadius * visualizationStyle.nodeScale
        let isCore = category.id == .core
        var material = PhysicallyBasedMaterial()
        let darken: CGFloat = selected ? 0.6 : pocketed ? 0.68 : 0.75
        material.baseColor = .init(tint: darkened(category.color.uiColor, by: darken))
        material.roughness = .init(floatLiteral: isCore ? 0.35 : 0.5)
        material.metallic = .init(floatLiteral: isCore ? 0.1 : 0.05)
        material.emissiveColor = .init(color: category.color.uiColor)
        // Founder core is the hero node — keep it noticeably lit even when
        // the camera is browsing another category.
        material.emissiveIntensity = isCore
            ? (selected ? 2.0 : 0.8)
            : (selected ? 1.5 : pocketed ? 0.5 : 0.18)
        material.emissiveIntensity *= visualizationStyle.glowBoost
        if selected {
            // Thin glossy shell over the matte base — "lit from within",
            // not a lampshade.
            material.clearcoat = .init(floatLiteral: 0.6)
            material.clearcoatRoughness = .init(floatLiteral: 0.2)
        }
        let node = ModelEntity(
            mesh: .generateSphere(radius: radius),
            materials: [material]
        )
        node.position = position
        if pocketed {
            // PHASE_2_PLAN step 5: pocket entities scale up by 1.18×.
            node.scale = SIMD3<Float>(repeating: PocketShellGeometry.pocketNodeScale)
        }
        if let tool {
            makeTappable(node, name: "tool:\(tool.id)", radius: max(radius * 1.6, 0.8))
        }
        return node
    }

    /// Mixes a color toward black by `fraction` (0 = unchanged, 1 = black).
    private static func darkened(_ color: UIColor, by fraction: CGFloat) -> UIColor {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let keep = 1 - fraction
        return UIColor(red: red * keep, green: green * keep, blue: blue * keep, alpha: 1)
    }
}

#Preview {
    UniverseView(
        selectedCategory: .design,
        selectedToolId: "figma",
        tools: UniverseSeed.tools,
        visualizationStyle: .orbitalGlass,
        onToolSelect: { _ in },
        onProximityEvent: { _ in }
    )
}
