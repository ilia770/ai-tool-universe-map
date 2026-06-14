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
            // Perf baseline (backlog 35): bracket the whole one-time scene
            // build so its cost is visible in Instruments. begin/end rather
            // than an `interval { }` closure because the make closure builds
            // in place and returns nothing — bracketing avoids reshaping it.
            let buildSignpost = UniversePerf.signposter.beginInterval("scene.build")
            defer { UniversePerf.signposter.endInterval("scene.build", buildSignpost) }
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
            // Founder core hero halo (backlog 27): a frosted translucent
            // shell layered around the core so it reads as the scene's hero.
            // Added once; additive to the core's existing emissive styling.
            universe.addChild(Self.makeFounderHalo(reduceMotion: reduceMotion))

            var anchors: [ProximityWatcherCore.Anchor] = []
            for category in UniverseSeed.categories where category.id != .core {
                let center = UniverseLayout.categoryPosition(angleDegrees: category.angle)
                anchors.append(ProximityWatcherCore.Anchor(id: category.id, position: center))
                let anchor = Self.makeCategoryAnchor(category: category, position: center)
                Self.styleAnchor(anchor, category: category, selected: category.id == selectedCategory)
                universe.addChild(anchor)
                universe.addChild(Self.makeCategoryLabel(category: category, position: center))
                // Static orbit ring encircling this category's tools
                // (backlog 23). Built once here; not in applyLayout.
                universe.addChild(Self.makeCategoryRing(category: category, position: center))
                if category.id == selectedCategory {
                    universe.addChild(PocketShellEntity.make(category: category, position: center, reduceMotion: reduceMotion))
                }

                // Structural graph edge: founder core (.zero) → this
                // category anchor. Brighter/thicker as the primary tier.
                universe.addChild(Self.makeLink(
                    from: .zero,
                    to: center,
                    color: category.color.uiColor,
                    opacity: 0.5,
                    thickness: 0.02,
                    name: "link:core-\(category.id.rawValue)"
                ))

                let categoryTools = UniverseSeed.tools(in: category.id)
                for (index, tool) in categoryTools.enumerated() {
                    let isPocket = category.id == selectedCategory
                    let node = Self.makeToolNode(
                        tool: tool,
                        category: category,
                        position: Self.toolPosition(tool: tool, category: category, index: index, count: categoryTools.count, pocketed: isPocket)
                    )
                    let isDimmed = selectedCategory != .core && category.id != selectedCategory
                    let isSelected = tool.id == selectedToolId
                    Self.styleToolNode(node, category: category, selected: isSelected, pocketed: isPocket, dimmed: isDimmed)
                    let baseScale = PocketTransition.toolNodeScale(
                        orbit: tool.orbit.rawValue,
                        selected: isSelected,
                        pocketed: isPocket
                    )
                    node.scale = SIMD3<Float>(repeating: baseScale)
                    universe.addChild(node)
                    // Selection pulse on the initially-selected node
                    // (backlog 24); no-op for the rest. reduceMotion → static.
                    if isSelected {
                        Self.applySelectionPulse(
                            node: node,
                            selected: true,
                            reduceMotion: reduceMotion,
                            baseScale: baseScale,
                            restTranslation: node.position
                        )
                    }

                    // Structural graph edge: category anchor → tool. Dimmer
                    // and thinner than core→category (secondary tier).
                    //
                    // v1 limitation: these lines are static, drawn once to
                    // the OVERVIEW tool position. When a pocket opens, its
                    // tool NODES re-lay-out to Fibonacci-sphere positions
                    // (applyLayout), but these lines are NOT updated — so in
                    // the open pocket they no longer reach their nodes. Using
                    // the overview position here keeps the founder/overview
                    // graph (the common case) correct; following the pocket
                    // re-layout is deferred to a later slice.
                    universe.addChild(Self.makeLink(
                        from: center,
                        to: Self.toolPosition(tool: tool, category: category, index: index, count: categoryTools.count, pocketed: false),
                        color: category.color.uiColor,
                        opacity: 0.22,
                        thickness: 0.012,
                        name: "link:\(category.id.rawValue)-\(tool.id)"
                    ))
                }
            }

            universe.components.set(UniverseStateComponent(
                activeCategory: selectedCategory,
                activeToolId: selectedToolId,
                anchors: anchors,
                camera: camera,
                onProximityEvent: onProximityEvent
            ))

            // Ambient cosmic backdrop (backlog 19): a static star field on a
            // shell far beyond the camera, so the universe sits in stars
            // rather than a flat void. Added once; not tappable, no animation.
            universe.addChild(StarFieldEntity.make())

            // Sparse ambient haze layer (backlog 20): large, very faint
            // translucent blobs at a mid shell radius — closer than the
            // stars, outside the node cloud — so the scene reads with cosmic
            // depth between the near nodes and the far star shell. Added once;
            // not tappable, no animation.
            universe.addChild(GalaxyDustEntity.make())

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
        // Double-tap a node to fly-to + select it (backlog 14). Registered
        // before the single-tap so the count:2 recognizer claims a double
        // tap; the single SpatialTapGesture still wins for lone taps.
        .gesture(
            SpatialTapGesture(count: 2)
                .targetedToAnyEntity()
                .onEnded { value in
                    handleDoubleTap(on: value.entity)
                }
        )
        .gesture(
            SpatialTapGesture()
                .targetedToAnyEntity()
                .onEnded { value in
                    handleTap(on: value.entity)
                }
        )
        // Drag on empty space orbits; pinch dollies. Both run alongside the
        // targeted tap gestures (which only fire when they hit an entity),
        // so a tap on a node still selects while a drag/pinch on the
        // backdrop manipulates the camera. minimumDistance keeps a slow tap
        // from registering as a 0-distance drag.
        .simultaneousGesture(
            DragGesture(minimumDistance: 10)
                .onChanged { value in
                    cameraController.orbitChanged(translation: value.translation)
                }
                .onEnded { _ in
                    cameraController.orbitEnded()
                }
        )
        .simultaneousGesture(
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

    /// Double-tap fly-to (backlog 14). On a tool node it selects the tool,
    /// which routes through `focusTool` upstream → category change →
    /// `retarget` animates the camera to that pocket framing. On a category
    /// anchor it opens the pocket via the same event path as single-tap.
    /// Same routing as `handleTap` today; the distinct fly-to feel comes
    /// from the camera move a selection already triggers. Empty-space
    /// double-tap-to-reset is a follow-up (a targeted tap can't observe an
    /// empty-space hit; wiring it cleanly without stealing single taps is
    /// deferred so this slice can't regress tap selection).
    private func handleDoubleTap(on entity: Entity) {
        handleTap(on: entity)
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
        // Perf baseline (backlog 35): measure the per-transition restyle/move
        // loop the review flagged (iterates ALL tool nodes, reallocates a
        // PhysicallyBasedMaterial per node per transition). Pure instrumentation.
        UniversePerf.interval("layout.apply") {
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
                let restTranslation = toolPosition(tool: tool, category: category, index: index, count: categoryTools.count, pocketed: isPocket)
                let baseScale = PocketTransition.toolNodeScale(
                    orbit: tool.orbit.rawValue,
                    selected: selected,
                    pocketed: isPocket
                )

                // Selection pulse (backlog 24). The persistent scene reuses
                // nodes, so this is robust to a node switching in/out of
                // selection: applySelectionPulse always stopAllAnimations()
                // first, clearing any stale pulse on a just-deselected node.
                // For the SELECTED node (and !reduceMotion) the pulse drives
                // its transform, so we must NOT also run move(to:) on it —
                // we snap it to its rest transform first, then start the
                // pulse. Every other node animates to rest via move(to:).
                if selected && !reduceMotion {
                    var rest = node.transform
                    rest.translation = restTranslation
                    rest.scale = SIMD3<Float>(repeating: baseScale)
                    node.transform = rest
                    applySelectionPulse(node: node, selected: true, reduceMotion: reduceMotion, baseScale: baseScale, restTranslation: restTranslation)
                } else {
                    // Clears any prior pulse, then animates to rest.
                    applySelectionPulse(node: node, selected: false, reduceMotion: reduceMotion, baseScale: baseScale, restTranslation: restTranslation)
                    var transform = node.transform
                    transform.translation = restTranslation
                    transform.scale = SIMD3<Float>(repeating: baseScale)
                    node.move(to: transform, relativeTo: node.parent, duration: duration, timingFunction: .easeInOut)
                }
            }
        }
        } // UniversePerf.interval("layout.apply")
    }

    // MARK: - Entity construction (base state; style applied separately)

    // MARK: - Connection lines (backlog 18, review Pillar-1)

    /// Shared unit box (1×1×1) every link reuses — links only differ by
    /// transform and material, so one mesh keeps allocations down.
    private static let linkMesh = MeshResource.generateBox(size: 1)

    /// Builds a static structural line spanning two points as a thin box,
    /// stretched/oriented via `LinkGeometry`. UnlitMaterial so lines read
    /// the same regardless of the key/fill rig. NOT tappable — no
    /// InputTargetComponent / CollisionComponent — so a link can never
    /// steal a tap from the node sitting under it.
    private static func makeLink(
        from: SIMD3<Float>,
        to: SIMD3<Float>,
        color: UIColor,
        opacity: Float,
        thickness: Float,
        name: String
    ) -> ModelEntity {
        var material = UnlitMaterial(color: color)
        material.blending = .transparent(opacity: .init(floatLiteral: opacity))
        let link = ModelEntity(mesh: linkMesh, materials: [material])
        link.name = name

        let t = LinkGeometry.transform(from: from, to: to, thickness: thickness)
        link.position = t.position
        link.scale = t.scale
        link.orientation = t.rotation
        return link
    }

    // MARK: - Category orbit ring (backlog 23, web CategoryRing parity)

    /// Radius of the flat orbit ring encircling a category's tool cloud.
    /// Web parity: `<circleGeometry args={[3.2, …]}>` — the circle the
    /// overview tools sit on (orbit radii top out at ~1.98 from the anchor,
    /// so 3.2 reads as a generous halo around them). Tunable.
    static let categoryRingRadius: Float = 3.2
    /// Thin tube so the ring reads as a drawn orbit line, not a donut.
    static let categoryRingTube: Float = 0.01
    /// Low opacity (web active ring opacity 0.2) so it whispers depth
    /// rather than competing with the nodes.
    static let categoryRingOpacity: Float = 0.18

    /// Builds a flat, thin orbit ring encircling a category's tool cloud —
    /// a torus (reusing the tested `PocketShellGeometry.torus`) tipped flat
    /// like the pocket-shell rings. UnlitMaterial in the category colour at
    /// low opacity. NOT tappable (no InputTargetComponent / collision) so it
    /// can never steal a tap from a node. Static: positioned once in the
    /// make closure, never restyled in applyLayout.
    private static func makeCategoryRing(category: ToolCategory, position: SIMD3<Float>) -> ModelEntity {
        let torus = PocketShellGeometry.torus(
            radius: categoryRingRadius,
            tube: categoryRingTube,
            radialSegments: 6,
            tubularSegments: 96
        )
        var descriptor = MeshDescriptor(name: "category-ring")
        descriptor.positions = MeshBuffer(torus.positions)
        descriptor.normals = MeshBuffer(torus.normals)
        descriptor.primitives = .triangles(torus.indices)
        let mesh = (try? MeshResource.generate(from: [descriptor]))
            ?? .generateSphere(radius: categoryRingTube)

        var material = UnlitMaterial(color: category.color.uiColor)
        material.blending = .transparent(opacity: .init(floatLiteral: categoryRingOpacity))

        let ring = ModelEntity(mesh: mesh, materials: [material])
        ring.name = "ring:\(category.id.rawValue)"
        ring.position = position
        // Web: rotation={[Math.PI / 2, 0, 0]} — lay the XY torus flat.
        ring.orientation = simd_quatf(angle: .pi / 2, axis: SIMD3<Float>(1, 0, 0))
        return ring
    }

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

    /// Billboarded 3D text label naming the category (its `shortName`),
    /// floating above the anchor. Static per category — the position is
    /// fixed, so it's built once in the make closure and never needs to flow
    /// through applyLayout. Not tappable (no InputTargetComponent / collision)
    /// so it can never steal a tap from the anchor sphere underneath it.
    ///
    /// `generateText` sizes in METERS — the font size IS the world height —
    /// so `labelFontSize` is tuned to read at the ~20-unit overview distance
    /// and `labelLift` clears the anchor sphere. Both are tunable.
    private static let labelFontSize: CGFloat = 0.8
    private static let labelLift: Float = 1.0

    private static func makeCategoryLabel(category: ToolCategory, position: SIMD3<Float>) -> Entity {
        let mesh = MeshResource.generateText(
            category.shortName,
            extrusionDepth: 0.01,
            font: .systemFont(ofSize: labelFontSize, weight: .semibold),
            containerFrame: .zero,
            alignment: .center,
            lineBreakMode: .byTruncatingTail
        )
        // UnlitMaterial so the label reads regardless of the key/fill rig.
        let label = ModelEntity(mesh: mesh, materials: [UnlitMaterial(color: category.color.uiColor)])

        // generateText's origin is the text's lower-left; recenter the mesh on
        // the entity origin by offsetting the model by -bounds.center so the
        // label sits centered (both axes) over the anchor.
        let center = mesh.bounds.center
        label.position = SIMD3<Float>(-center.x, -center.y, -center.z)

        let root = Entity()
        root.name = "label:\(category.id.rawValue)"
        root.position = position + SIMD3<Float>(0, PocketTransition.baseAnchorRadius + labelLift, 0)
        // iOS 18 RealityKit: face the active camera every frame.
        root.components.set(BillboardComponent())
        root.addChild(label)
        return root
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

    // MARK: - Founder core hero halo (backlog 27)

    /// Radius of the frosted shell around the founder core. The core node is
    /// generated at ~0.24 and scaled to ~0.46 when selected; the halo at 1.2
    /// reads as a soft glow envelope larger than the core itself. Tunable.
    static let founderHaloRadius: Float = 1.2
    /// Very low opacity so the halo is a frosted glow, not a solid ball.
    static let founderHaloOpacity: Float = 0.12
    /// Slow breathing scale amplitude (±) and half-period for the halo.
    static let founderHaloBreathScale: Float = 0.06
    static let founderHaloBreathDuration: TimeInterval = 2.6

    /// Static frosted translucent shell centred at the origin, layered AROUND
    /// the founder-os core node to make it read as the scene's hero. Built
    /// once in the make closure; not tappable (no InputTargetComponent /
    /// collision) so it never steals a tap from the core node inside it, and
    /// not restyled in applyLayout. With motion allowed it slowly breathes.
    private static func makeFounderHalo(reduceMotion: Bool) -> ModelEntity {
        let coreColor = UniverseSeed.category(.core).color.uiColor
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: coreColor)
        material.roughness = .init(floatLiteral: 0.85)
        material.metallic = .init(floatLiteral: 0.0)
        material.blending = .transparent(opacity: .init(floatLiteral: founderHaloOpacity))
        material.emissiveColor = .init(color: coreColor)
        material.emissiveIntensity = 0.4

        let halo = ModelEntity(mesh: .generateSphere(radius: founderHaloRadius), materials: [material])
        halo.name = "founder-halo"
        halo.position = .zero

        if !reduceMotion {
            var peak = halo.transform
            peak.scale = SIMD3<Float>(repeating: 1 + founderHaloBreathScale)
            let breathe = FromToByAnimation<Transform>(
                from: halo.transform,
                to: peak,
                duration: founderHaloBreathDuration,
                timing: .easeInOut,
                bindTarget: .transform,
                repeatMode: .autoReverse
            )
            if let resource = try? AnimationResource.generate(with: breathe) {
                halo.playAnimation(resource)
            }
        }
        return halo
    }

    // MARK: - Selection pulse (backlog 24)

    /// Fraction the selected node's scale bobs by — a gentle ±3 % breath so
    /// the eye is drawn without the node visibly jumping. Tunable.
    static let selectionPulseScale: Float = 0.03
    /// Half-period of the pulse: one ease leg from base→peak before the
    /// autoreverse swings back. ~1.1 s gives a slow, calm breath.
    static let selectionPulseDuration: TimeInterval = 1.1

    /// Applies (or removes) the selection pulse on a tool node.
    ///
    /// The persistent scene reuses node entities across selection changes,
    /// so this must be robust to a node being re-driven: it always
    /// `stopAllAnimations()` and resets the node to its base scale first,
    /// THEN, only when the node is selected AND motion is allowed, plays a
    /// gentle repeating autoreversing scale bob. With reduce-motion the
    /// node simply sits at its (already brighter, clearcoated) base scale —
    /// the material is the highlight, no animation.
    ///
    /// `baseScale` is the node's resting uniform scale (PocketTransition
    /// .toolNodeScale for its current state); the pulse oscillates around it.
    /// `restTranslation` is the node's final resting position — passed
    /// explicitly (not read off `node.transform`) because in applyLayout the
    /// node's `move(to:)` may still be in flight when this runs.
    private static func applySelectionPulse(
        node: ModelEntity,
        selected: Bool,
        reduceMotion: Bool,
        baseScale: Float,
        restTranslation: SIMD3<Float>
    ) {
        node.stopAllAnimations()
        var base = node.transform
        base.translation = restTranslation
        base.scale = SIMD3<Float>(repeating: baseScale)

        guard selected, !reduceMotion else {
            // Unselected (or reduce-motion): leave the node where it is /
            // let its move settle; just ensure no stale pulse is running.
            return
        }

        var peak = base
        peak.scale = SIMD3<Float>(repeating: baseScale * (1 + selectionPulseScale))
        let pulse = FromToByAnimation<Transform>(
            from: base,
            to: peak,
            duration: selectionPulseDuration,
            timing: .easeInOut,
            bindTarget: .transform,
            repeatMode: .autoReverse
        )
        if let resource = try? AnimationResource.generate(with: pulse) {
            node.playAnimation(resource)
        }
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
