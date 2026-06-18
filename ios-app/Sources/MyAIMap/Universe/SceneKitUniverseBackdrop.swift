import SceneKit
import SwiftUI

private let sceneStageOrder: [WorkflowStageId] = [
    .research,
    .planning,
    .execution,
    .approval,
    .review,
]

/// Native 3D backing layer for the AI Universe.
///
/// SceneKit owns only the cinematic depth: spheres, lights, stars, halos,
/// camera gestures, and hit targets. SwiftUI remains the readable overlay for
/// labels, chat, settings, and controls.
struct SceneKitUniverseBackdrop: UIViewRepresentable {
    let selectedCategory: ToolCategoryId
    let selectedToolId: String
    let tools: [Tool]
    let visualizationStyle: VisualizationStyle
    let onCategorySelect: (ToolCategoryId) -> Void
    let onToolSelect: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCategorySelect: onCategorySelect, onToolSelect: onToolSelect)
    }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView(frame: .zero)
        view.backgroundColor = .clear
        view.isOpaque = false
        view.antialiasingMode = .multisampling4X
        view.rendersContinuously = true
        view.preferredFramesPerSecond = 60
        view.allowsCameraControl = false

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        let pinch = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePinch(_:)))
        tap.delegate = context.coordinator
        pan.delegate = context.coordinator
        pinch.delegate = context.coordinator
        view.addGestureRecognizer(tap)
        view.addGestureRecognizer(pan)
        view.addGestureRecognizer(pinch)

        context.coordinator.view = view
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        context.coordinator.onCategorySelect = onCategorySelect
        context.coordinator.onToolSelect = onToolSelect
        context.coordinator.rebuildScene(
            in: view,
            selectedCategory: selectedCategory,
            selectedToolId: selectedToolId,
            tools: tools,
            visualizationStyle: visualizationStyle
        )
    }

    @MainActor
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        weak var view: SCNView?
        var onCategorySelect: (ToolCategoryId) -> Void
        var onToolSelect: (String) -> Void
        private var lastSignature = ""
        private var cameraRig: SCNNode?
        private var cameraNode: SCNNode?
        private var baseOrthographicScale: CGFloat = 8.8
        private var orbitYaw: Float = -0.10
        private var orbitPitch: Float = -0.08
        private var panStartYaw: Float = -0.10
        private var panStartPitch: Float = -0.08
        private var zoomScale: CGFloat = 1.0
        private var pinchStartZoom: CGFloat = 1.0

        init(onCategorySelect: @escaping (ToolCategoryId) -> Void, onToolSelect: @escaping (String) -> Void) {
            self.onCategorySelect = onCategorySelect
            self.onToolSelect = onToolSelect
        }

        func rebuildScene(
            in view: SCNView,
            selectedCategory: ToolCategoryId,
            selectedToolId: String,
            tools: [Tool],
            visualizationStyle: VisualizationStyle
        ) {
            let signature = [
                selectedCategory.rawValue,
                selectedToolId,
                visualizationStyle.rawValue,
                tools.map(\.id).joined(separator: "|"),
            ].joined(separator: "::")
            guard signature != lastSignature else { return }
            lastSignature = signature

            let scene = SCNScene()
            scene.background.contents = UIColor.clear
            scene.rootNode.addChildNode(cameraRigNode(for: visualizationStyle))
            addLights(to: scene)
            addStars(to: scene, tint: UniverseSeed.category(selectedCategory).color.uiColor)
            addOrbitRings(to: scene, selectedCategory: selectedCategory, visualizationStyle: visualizationStyle)
            addPlanets(
                to: scene,
                selectedCategory: selectedCategory,
                selectedToolId: selectedToolId,
                tools: tools,
                visualizationStyle: visualizationStyle
            )

            view.scene = scene
            applyCameraTransform()
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let view else { return }
            let point = gesture.location(in: view)
            guard let hit = view.hitTest(point, options: [SCNHitTestOption.firstFoundOnly: true]).first else { return }
            guard let name = namedNode(from: hit.node)?.name else { return }
            if name.hasPrefix("tool:") {
                onToolSelect(String(name.dropFirst("tool:".count)))
            } else if name.hasPrefix("category:") {
                let raw = String(name.dropFirst("category:".count))
                if let category = ToolCategoryId(rawValue: raw) {
                    onCategorySelect(category)
                }
            }
        }

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let cameraRig else { return }
            if gesture.state == .began {
                panStartYaw = orbitYaw
                panStartPitch = orbitPitch
                BrandHaptics.fire(.light)
            }

            let translation = gesture.translation(in: gesture.view)
            orbitYaw = panStartYaw + Float(translation.x) * 0.0055
            orbitPitch = clamp(panStartPitch + Float(-translation.y) * 0.0032, min: -0.78, max: 0.52)

            SCNTransaction.begin()
            SCNTransaction.animationDuration = gesture.state == .ended || gesture.state == .cancelled ? 0.28 : 0
            SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeOut)
            cameraRig.eulerAngles = SCNVector3(orbitPitch, orbitYaw, 0)
            SCNTransaction.commit()

            if gesture.state == .ended || gesture.state == .cancelled {
                BrandHaptics.fire(.light)
            }
        }

        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            guard let camera = cameraNode?.camera else { return }
            if gesture.state == .began {
                pinchStartZoom = zoomScale
                BrandHaptics.fire(.light)
            }

            zoomScale = clamp(pinchStartZoom * gesture.scale, min: 0.66, max: 1.95)
            camera.orthographicScale = baseOrthographicScale / zoomScale

            if gesture.state == .ended || gesture.state == .cancelled {
                SCNTransaction.begin()
                SCNTransaction.animationDuration = 0.22
                SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeOut)
                camera.orthographicScale = baseOrthographicScale / zoomScale
                SCNTransaction.commit()
                gesture.scale = 1
            }
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            true
        }

        private func cameraRigNode(for style: VisualizationStyle) -> SCNNode {
            let rig = SCNNode()
            rig.name = "camera-rig"

            let camera = SCNCamera()
            camera.usesOrthographicProjection = true
            baseOrthographicScale = style.baseOrthographicScale
            camera.orthographicScale = baseOrthographicScale / zoomScale
            camera.zNear = 0.1
            camera.zFar = 100

            let node = SCNNode()
            node.camera = camera
            node.position = style.cameraPosition
            rig.addChildNode(node)
            cameraRig = rig
            cameraNode = node
            applyCameraTransform(to: rig)
            return rig
        }

        private func applyCameraTransform() {
            guard let cameraRig else { return }
            applyCameraTransform(to: cameraRig)
            cameraNode?.camera?.orthographicScale = baseOrthographicScale / zoomScale
        }

        private func applyCameraTransform(to rig: SCNNode) {
            rig.eulerAngles = SCNVector3(orbitPitch, orbitYaw, 0)
        }

        private func addLights(to scene: SCNScene) {
            let key = SCNLight()
            key.type = .omni
            key.intensity = 820
            key.temperature = 8200
            let keyNode = SCNNode()
            keyNode.light = key
            keyNode.position = SCNVector3(-3.2, 4.5, 6.8)
            scene.rootNode.addChildNode(keyNode)

            let ambient = SCNLight()
            ambient.type = .ambient
            ambient.intensity = 170
            ambient.color = UIColor(red: 0.42, green: 0.64, blue: 1, alpha: 1)
            let ambientNode = SCNNode()
            ambientNode.light = ambient
            scene.rootNode.addChildNode(ambientNode)
        }

        private func addStars(to scene: SCNScene, tint: UIColor) {
            for index in 0..<110 {
                let radius = CGFloat(index % 7 == 0 ? 0.012 : 0.007)
                let star = SCNSphere(radius: radius)
                star.segmentCount = 6
                let material = SCNMaterial()
                material.diffuse.contents = index % 5 == 0 ? tint.withAlphaComponent(0.7) : UIColor.white.withAlphaComponent(0.75)
                material.emission.contents = material.diffuse.contents
                star.materials = [material]

                let node = SCNNode(geometry: star)
                node.position = SCNVector3(
                    Float(seed(index, 73, modulo: 997) * 9.4 - 4.7),
                    Float(seed(index, 131, modulo: 991) * 9.8 - 4.9),
                    Float(-5.5 - seed(index, 47, modulo: 983) * 5.5)
                )
                scene.rootNode.addChildNode(node)
            }
        }

        private func addOrbitRings(to scene: SCNScene, selectedCategory: ToolCategoryId, visualizationStyle: VisualizationStyle) {
            let tint = UniverseSeed.category(selectedCategory).color.uiColor
            for index in 0..<4 {
                let torus = SCNTorus(ringRadius: CGFloat(1.55 + Double(index) * 0.58), pipeRadius: index == 0 ? 0.006 : 0.004)
                torus.ringSegmentCount = 160
                torus.pipeSegmentCount = 6
                let material = SCNMaterial()
                material.diffuse.contents = tint.withAlphaComponent(index == 0 ? 0.30 : 0.12)
                material.emission.contents = tint.withAlphaComponent(index == 0 ? 0.18 : 0.08)
                torus.materials = [material]
                let node = SCNNode(geometry: torus)
                node.name = "orbit-\(index)"
                node.scale.y = Float(0.58 + Double(index) * 0.04)
                node.eulerAngles.z = Float(index) * 0.14
                node.runAction(.repeatForever(.rotateBy(x: 0, y: 0, z: CGFloat(index.isMultiple(of: 2) ? 0.18 : -0.14), duration: 12 + Double(index) * 5)))
                scene.rootNode.addChildNode(node)
            }

            guard visualizationStyle == .force3D else { return }
            addStagePath(to: scene, tint: tint)
        }

        private func addStagePath(to scene: SCNScene, tint: UIColor) {
            let points = sceneStageOrder.map { stageScenePosition(for: $0) }
            for (index, point) in points.enumerated() {
                let marker = SCNSphere(radius: 0.045)
                marker.segmentCount = 12
                let material = SCNMaterial()
                material.diffuse.contents = tint.withAlphaComponent(0.75)
                material.emission.contents = tint.withAlphaComponent(0.46)
                marker.materials = [material]
                let node = SCNNode(geometry: marker)
                node.position = point
                scene.rootNode.addChildNode(node)

                if index > 0 {
                    addLine(from: points[index - 1], to: point, tint: tint.withAlphaComponent(0.22), scene: scene)
                }
            }
        }

        private func addLine(from start: SCNVector3, to end: SCNVector3, tint: UIColor, scene: SCNScene) {
            let source = SCNGeometrySource(vertices: [start, end])
            let element = SCNGeometryElement(indices: [Int32(0), Int32(1)], primitiveType: .line)
            let geometry = SCNGeometry(sources: [source], elements: [element])
            let material = SCNMaterial()
            material.diffuse.contents = tint
            material.emission.contents = tint
            geometry.materials = [material]
            scene.rootNode.addChildNode(SCNNode(geometry: geometry))
        }

        private func addPlanets(
            to scene: SCNScene,
            selectedCategory: ToolCategoryId,
            selectedToolId: String,
            tools: [Tool],
            visualizationStyle: VisualizationStyle
        ) {
            let coreCategory = UniverseSeed.category(.core)
            scene.rootNode.addChildNode(
                planetNode(
                    name: "tool:founder-os",
                    radius: 0.58,
                    color: coreCategory.color.uiColor,
                    position: SCNVector3(0, 0, 0.1),
                    selected: selectedToolId == "founder-os",
                    title: "Founder OS",
                    subtitle: "Core"
                )
            )

            for category in UniverseSeed.categories where category.id != .core {
                let selected = category.id == selectedCategory
                let position = categoryPosition(category, style: visualizationStyle)
                scene.rootNode.addChildNode(
                    planetNode(
                        name: "category:\(category.id.rawValue)",
                        radius: selected ? 0.38 : 0.29,
                        color: category.color.uiColor,
                        position: position,
                        selected: selected,
                        title: category.shortName,
                        subtitle: "\(tools.filter { $0.category == category.id }.count) tools"
                    )
                )
            }

            let visibleTools: [Tool]
            if selectedCategory == .core {
                visibleTools = UniverseSeed.categories
                    .filter { $0.id != .core }
                    .flatMap { category in tools.filter { $0.category == category.id }.prefix(2) }
            } else {
                visibleTools = tools.filter { $0.category == selectedCategory }
            }

            for (index, tool) in visibleTools.enumerated() {
                let category = UniverseSeed.category(tool.category)
                let selected = tool.id == selectedToolId
                let position = toolPosition(tool, index: index, selectedCategory: selectedCategory, style: visualizationStyle)
                scene.rootNode.addChildNode(
                    planetNode(
                        name: "tool:\(tool.id)",
                        radius: selected ? 0.28 : 0.18,
                        color: category.color.uiColor,
                        position: position,
                        selected: selected,
                        title: tool.name,
                        subtitle: stageShortLabel(tool.stage)
                    )
                )
            }
        }

        private func planetNode(
            name: String,
            radius: CGFloat,
            color: UIColor,
            position: SCNVector3,
            selected: Bool,
            title: String,
            subtitle: String
        ) -> SCNNode {
            let wrapper = SCNNode()
            wrapper.name = name
            wrapper.position = position

            let halo = SCNSphere(radius: radius * 1.68)
            halo.segmentCount = 32
            let haloMaterial = SCNMaterial()
            haloMaterial.diffuse.contents = color.withAlphaComponent(selected ? 0.18 : 0.09)
            haloMaterial.emission.contents = color.withAlphaComponent(selected ? 0.28 : 0.14)
            haloMaterial.transparency = selected ? 0.42 : 0.25
            haloMaterial.writesToDepthBuffer = false
            halo.materials = [haloMaterial]
            wrapper.addChildNode(SCNNode(geometry: halo))

            let sphere = SCNSphere(radius: radius)
            sphere.segmentCount = 48
            let material = SCNMaterial()
            material.lightingModel = .physicallyBased
            material.diffuse.contents = color
            material.emission.contents = color.withAlphaComponent(selected ? 0.42 : 0.20)
            material.specular.contents = UIColor.white.withAlphaComponent(0.72)
            material.roughness.contents = 0.28
            material.metalness.contents = 0.08
            sphere.materials = [material]

            let planet = SCNNode(geometry: sphere)
            planet.name = name
            planet.runAction(.repeatForever(.rotateBy(x: 0, y: CGFloat(selected ? 1.2 : 0.7), z: 0, duration: selected ? 7.5 : 10.5)))
            wrapper.addChildNode(planet)

            let ring = SCNTorus(ringRadius: radius * 1.26, pipeRadius: max(radius * 0.018, 0.004))
            ring.ringSegmentCount = 96
            ring.pipeSegmentCount = 6
            let ringMaterial = SCNMaterial()
            ringMaterial.diffuse.contents = color.withAlphaComponent(selected ? 0.58 : 0.28)
            ringMaterial.emission.contents = color.withAlphaComponent(selected ? 0.34 : 0.16)
            ring.materials = [ringMaterial]
            let ringNode = SCNNode(geometry: ring)
            ringNode.eulerAngles = SCNVector3(0.68, 0.18, selected ? -0.42 : -0.28)
            ringNode.opacity = selected ? 1 : 0.72
            wrapper.addChildNode(ringNode)

            let label = labelNode(title: title, subtitle: subtitle, color: color, selected: selected)
            label.position = SCNVector3(0, Float(-radius * 1.82), 0)
            wrapper.addChildNode(label)

            return wrapper
        }

        private func labelNode(title: String, subtitle: String, color: UIColor, selected: Bool) -> SCNNode {
            let text = SCNText(string: subtitle.isEmpty ? title : "\(title)\n\(subtitle)", extrusionDepth: 0.004)
            text.font = UIFont.systemFont(ofSize: selected ? 16 : 13, weight: selected ? .bold : .semibold)
            text.alignmentMode = CATextLayerAlignmentMode.center.rawValue
            text.flatness = 0.2
            let material = SCNMaterial()
            material.diffuse.contents = UIColor.white.withAlphaComponent(selected ? 0.95 : 0.78)
            material.emission.contents = UIColor.white.withAlphaComponent(selected ? 0.34 : 0.18)
            text.materials = [material]

            let label = SCNNode(geometry: text)
            let bounds = text.boundingBox
            label.pivot = SCNMatrix4MakeTranslation(
                (bounds.max.x - bounds.min.x) / 2 + bounds.min.x,
                (bounds.max.y - bounds.min.y) / 2 + bounds.min.y,
                0
            )
            label.scale = SCNVector3(selected ? 0.017 : 0.014, selected ? 0.017 : 0.014, 0.014)
            label.constraints = [SCNBillboardConstraint()]

            let plate = SCNPlane(width: selected ? 1.38 : 1.04, height: selected ? 0.44 : 0.34)
            plate.cornerRadius = selected ? 0.14 : 0.11
            let plateMaterial = SCNMaterial()
            plateMaterial.diffuse.contents = UIColor.black.withAlphaComponent(selected ? 0.72 : 0.50)
            plateMaterial.emission.contents = color.withAlphaComponent(selected ? 0.10 : 0.05)
            plate.materials = [plateMaterial]
            let plateNode = SCNNode(geometry: plate)
            plateNode.position = SCNVector3(0, selected ? -0.005 : -0.004, -0.012)
            plateNode.constraints = [SCNBillboardConstraint()]

            let wrapper = SCNNode()
            wrapper.addChildNode(plateNode)
            wrapper.addChildNode(label)
            return wrapper
        }

        private func categoryPosition(_ category: ToolCategory, style: VisualizationStyle) -> SCNVector3 {
            let radians = Double(category.angle) * .pi / 180
            let radiusX = style == .force3D ? 3.0 : 3.1
            let radiusY = style == .force3D ? 2.15 : 2.05
            return SCNVector3(
                Float(cos(radians) * radiusX),
                Float(-sin(radians) * radiusY),
                Float(sin(radians) * (style == .force3D ? 0.9 : 0.36))
            )
        }

        private func toolPosition(_ tool: Tool, index: Int, selectedCategory: ToolCategoryId, style: VisualizationStyle) -> SCNVector3 {
            if style == .force3D {
                let stage = stageScenePosition(for: tool.stage)
                let radians = (Double(tool.angle) + Double(index) * 29) * .pi / 180
                return SCNVector3(
                    stage.x + Float(cos(radians) * 0.34),
                    stage.y + Float(sin(radians) * 0.22),
                    stage.z + Float(tool.orbit.rawValue) * 0.13
                )
            }

            let category = UniverseSeed.category(tool.category)
            let base = selectedCategory == .core ? categoryPosition(category, style: style) : SCNVector3Zero
            let radians = (Double(tool.angle) + Double(index) * 22) * .pi / 180
            let radius = 0.6 + Double(tool.orbit.rawValue) * 0.28
            return SCNVector3(
                base.x + Float(cos(radians) * radius),
                base.y + Float(-sin(radians) * radius * 0.68),
                base.z + Float(tool.orbit.rawValue) * 0.11
            )
        }

        private func stageScenePosition(for stage: WorkflowStageId) -> SCNVector3 {
            let index = sceneStageOrder.firstIndex(of: stage) ?? 0
            let step = 1.35
            let x = (Double(index) - 2.0) * step
            let y = -2.62 + sin(Double(index) * 0.8) * 0.2
            return SCNVector3(Float(x), Float(y), Float(0.45 + Double(index) * 0.08))
        }

        private func seed(_ index: Int, _ multiplier: Int, modulo: Int) -> Double {
            Double((index * multiplier + 19) % modulo) / Double(modulo)
        }

        private func stageShortLabel(_ stage: WorkflowStageId) -> String {
            switch stage {
            case .research: return "Research"
            case .planning: return "Plan"
            case .execution: return "Build"
            case .approval: return "Approve"
            case .review: return "Review"
            }
        }

        private func namedNode(from node: SCNNode) -> SCNNode? {
            var current: SCNNode? = node
            while let candidate = current {
                if let name = candidate.name, name.hasPrefix("tool:") || name.hasPrefix("category:") {
                    return candidate
                }
                current = candidate.parent
            }
            return nil
        }

        private func clamp<T: Comparable>(_ value: T, min minValue: T, max maxValue: T) -> T {
            Swift.min(Swift.max(value, minValue), maxValue)
        }
    }
}

private extension VisualizationStyle {
    var baseOrthographicScale: CGFloat {
        switch self {
        case .atlasOverlay: return 9.5
        case .kineticPockets: return 8.15
        case .force3D: return 7.35
        case .orbitalGlass: return 8.7
        }
    }

    var cameraPosition: SCNVector3 {
        switch self {
        case .atlasOverlay: return SCNVector3(0, 0.35, 12.2)
        case .kineticPockets: return SCNVector3(0, 0.12, 10.7)
        case .force3D: return SCNVector3(0, 0.62, 9.8)
        case .orbitalGlass: return SCNVector3(0, 0.24, 11.3)
        }
    }
}
