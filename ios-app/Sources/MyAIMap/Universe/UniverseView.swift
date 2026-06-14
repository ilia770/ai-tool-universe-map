import SwiftUI
import RealityKit

/// Native RealityKit universe scene.
///
/// The scene is PERSISTENT (backlog task 16): it is built once in the
/// RealityView make closure and never torn down. Category / tool
/// selection changes flow through the update closure, which moves and
/// restyles the existing entities with animated transforms — so the
/// proximity system's cooldown state, the ring spins, and the camera
/// all survive a transition instead of rebuilding from black.
struct UniverseView: View {
    let selectedCategory: ToolCategoryId
    let selectedToolId: String
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
            universe.name = "universe"
            content.add(universe)

            let camera = PerspectiveCamera()
            universe.addChild(camera)
            cameraController.attach(camera, mode: viewMode, target: lookAtPosition(for: selectedCategory))

            let core = Self.makeToolNode(
                tool: UniverseSeed.tools.first { $0.id == "founder-os" },
                category: UniverseSeed.category(.core),
                position: .zero
            )
            Self.styleToolNode(core, category: UniverseSeed.category(.core), selected: selectedCategory == .core, pocketed: false)
            universe.addChild(core)

            var anchors: [ProximityWatcherCore.Anchor] = []
            for category in UniverseSeed.categories where category.id != .core {
                let center = UniverseLayout.categoryPosition(angleDegrees: category.angle)
                anchors.append(ProximityWatcherCore.Anchor(id: category.id, position: center))
                let anchor = Self.makeCategoryAnchor(category: category, position: center)
                Self.styleAnchor(anchor, category: category, selected: category.id == selectedCategory)
                universe.addChild(anchor)
                if category.id == selectedCategory {
                    universe.addChild(PocketShellEntity.make(category: category, position: center, reduceMotion: reduceMotion))
                }

                let categoryTools = UniverseSeed.tools(in: category.id)
                for (index, tool) in categoryTools.enumerated() {
                    let isPocket = category.id == selectedCategory
                    let node = Self.makeToolNode(
                        tool: tool,
                        category: category,
                        position: Self.toolPosition(tool: tool, category: category, index: index, count: categoryTools.count, pocketed: isPocket)
                    )
                    let isDimmed = selectedCategory != .core && category.id != selectedCategory
                    Self.styleToolNode(node, category: category, selected: tool.id == selectedToolId, pocketed: isPocket, dimmed: isDimmed)
                    node.scale = SIMD3<Float>(repeating: PocketTransition.toolNodeScale(
                        orbit: tool.orbit.rawValue,
                        selected: tool.id == selectedToolId,
                        pocketed: isPocket
                    ))
                    universe.addChild(node)
                }
            }

            universe.components.set(UniverseStateComponent(
                activeCategory: selectedCategory,
                activeToolId: selectedToolId,
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
        } update: { content in
            guard let universe = content.entities.first(where: { $0.name == "universe" }),
                  let state = universe.components[UniverseStateComponent.self] else { return }
            let categoryChanged = state.activeCategory != selectedCategory
            let toolChanged = state.activeToolId != selectedToolId
            guard categoryChanged || toolChanged else { return }

            universe.components.set(UniverseStateComponent(
                activeCategory: selectedCategory,
                activeToolId: selectedToolId,
                anchors: state.anchors,
                camera: state.camera,
                onProximityEvent: state.onProximityEvent
            ))

            if categoryChanged {
                cameraController.retarget(
                    mode: viewMode,
                    target: lookAtPosition(for: selectedCategory),
                    reduceMotion: reduceMotion
                )
                universe.findEntity(named: "pocket-shell")?.removeFromParent()
                if selectedCategory != .core {
                    let category = UniverseSeed.category(selectedCategory)
                    universe.addChild(PocketShellEntity.make(
                        category: category,
                        position: UniverseLayout.categoryPosition(angleDegrees: category.angle),
                        reduceMotion: reduceMotion
                    ))
                }
            }

            Self.applyLayout(
                universe: universe,
                selectedCategory: selectedCategory,
                selectedToolId: selectedToolId,
                animated: categoryChanged,
                reduceMotion: reduceMotion
            )
        }
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

    // MARK: - Persistent-scene layout

    private static func toolPosition(tool: Tool, category: ToolCategory, index: Int, count: Int, pocketed: Bool) -> SIMD3<Float> {
        pocketed
            ? UniverseLayout.pocketToolPosition(
                angleDegrees: tool.angle,
                orbit: tool.orbit,
                categoryAngleDegrees: category.angle,
                slotIndex: index,
                slotCount: max(count, 1)
            )
            : UniverseLayout.toolPosition(
                angleDegrees: tool.angle,
                orbit: tool.orbit,
                categoryAngleDegrees: category.angle
            )
    }

    /// Moves and restyles every node for the new selection. Materials snap
    /// (RealityKit can't tween them); transforms animate via Entity.move.
    private static func applyLayout(
        universe: Entity,
        selectedCategory: ToolCategoryId,
        selectedToolId: String,
        animated: Bool,
        reduceMotion: Bool
    ) {
        let duration = reduceMotion
            ? PocketTransition.reducedDuration
            : (animated ? PocketTransition.duration : PocketTransition.reducedDuration)

        if let core = universe.findEntity(named: "tool:founder-os") as? ModelEntity {
            styleToolNode(core, category: UniverseSeed.category(.core), selected: selectedCategory == .core, pocketed: false)
        }

        for category in UniverseSeed.categories where category.id != .core {
            let isPocket = category.id == selectedCategory
            if let anchor = universe.findEntity(named: "cat:\(category.id.rawValue)") as? ModelEntity {
                styleAnchor(anchor, category: category, selected: isPocket)
                var transform = anchor.transform
                transform.scale = SIMD3<Float>(repeating: PocketTransition.anchorScale(selected: isPocket))
                anchor.move(to: transform, relativeTo: anchor.parent, duration: duration, timingFunction: .easeInOut)
            }

            let categoryTools = UniverseSeed.tools(in: category.id)
            for (index, tool) in categoryTools.enumerated() {
                guard let node = universe.findEntity(named: "tool:\(tool.id)") as? ModelEntity else { continue }
                let selected = tool.id == selectedToolId
                let isDimmed = selectedCategory != .core && category.id != selectedCategory
                styleToolNode(node, category: category, selected: selected, pocketed: isPocket, dimmed: isDimmed)
                var transform = node.transform
                transform.translation = toolPosition(tool: tool, category: category, index: index, count: categoryTools.count, pocketed: isPocket)
                transform.scale = SIMD3<Float>(repeating: PocketTransition.toolNodeScale(
                    orbit: tool.orbit.rawValue,
                    selected: selected,
                    pocketed: isPocket
                ))
                node.move(to: transform, relativeTo: node.parent, duration: duration, timingFunction: .easeInOut)
            }
        }
    }

    // MARK: - Entity construction (base state; style applied separately)

    private static func makeTappable(_ entity: ModelEntity, name: String, radius: Float) {
        entity.name = name
        entity.components.set(InputTargetComponent())
        entity.components.set(CollisionComponent(shapes: [.generateSphere(radius: radius)]))
    }

    private static func makeCategoryAnchor(category: ToolCategory, position: SIMD3<Float>) -> ModelEntity {
        let anchor = ModelEntity(mesh: .generateSphere(radius: PocketTransition.baseAnchorRadius))
        anchor.position = position
        // Oversized hit shape — anchors are small targets at overview distance.
        makeTappable(anchor, name: "cat:\(category.id.rawValue)", radius: max(PocketTransition.baseAnchorRadius * 1.8, 1.1))
        return anchor
    }

    private static func makeToolNode(tool: Tool?, category: ToolCategory, position: SIMD3<Float>) -> ModelEntity {
        let baseRadius = PocketTransition.baseToolRadius(orbit: tool?.orbit.rawValue ?? 0)
        let node = ModelEntity(mesh: .generateSphere(radius: baseRadius))
        node.position = position
        if let tool {
            makeTappable(node, name: "tool:\(tool.id)", radius: max(baseRadius * 1.6, 0.8))
        }
        return node
    }

    // MARK: - Materials

    /// Soft matte orb: category color mixed well toward black for the base,
    /// with a gentle category-hued emissive carrying the selection hierarchy
    /// (selected > pocketed > overview-distant).
    private static func styleToolNode(_ node: ModelEntity, category: ToolCategory, selected: Bool, pocketed: Bool, dimmed: Bool = false) {
        let isCore = category.id == .core
        var material = PhysicallyBasedMaterial()
        // Foreign nodes recede further when a pocket is open (web parity:
        // ToolNode.tsx dims out-of-category tools so the open pocket reads
        // as focused). The dim only applies to non-selected, non-pocketed
        // foreign nodes — the founder core never dims.
        let darken: CGFloat = dimmed ? 0.85 : selected ? 0.6 : pocketed ? 0.68 : 0.75
        material.baseColor = .init(tint: darkened(category.color.uiColor, by: darken))
        material.roughness = .init(floatLiteral: isCore ? 0.35 : 0.5)
        material.metallic = .init(floatLiteral: isCore ? 0.1 : 0.05)
        material.emissiveColor = .init(color: category.color.uiColor)
        // Founder core is the hero node — keep it noticeably lit even when
        // the camera is browsing another category.
        material.emissiveIntensity = isCore
            ? (selected ? 2.0 : 0.8)
            : (dimmed ? 0.06 : selected ? 1.5 : pocketed ? 0.5 : 0.18)
        if selected {
            // Thin glossy shell over the matte base — "lit from within",
            // not a lampshade.
            material.clearcoat = .init(floatLiteral: 0.6)
            material.clearcoatRoughness = .init(floatLiteral: 0.2)
        }
        node.model?.materials = [material]
    }

    /// Frosted translucent category sphere: matte PBR glass tinted by the
    /// category hue, with a faint emissive lift so the shell reads as a
    /// lit volume instead of a flat colored ball.
    private static func styleAnchor(_ anchor: ModelEntity, category: ToolCategory, selected: Bool) {
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: darkened(category.color.uiColor, by: 0.45))
        material.roughness = .init(floatLiteral: 0.6)
        material.metallic = .init(floatLiteral: 0.0)
        material.blending = .transparent(opacity: .init(floatLiteral: selected ? 0.9 : 0.5))
        material.emissiveColor = .init(color: category.color.uiColor)
        material.emissiveIntensity = selected ? 0.65 : 0.28
        anchor.model?.materials = [material]
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
        onToolSelect: { _ in },
        onProximityEvent: { _ in }
    )
}
