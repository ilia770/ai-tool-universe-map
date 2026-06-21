import SwiftUI

enum UniverseGraphNodeKind: Equatable {
    case core
    case category
    case tool
}

struct UniverseGraphNode: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let category: ToolCategoryId
    let toolID: String?
    let kind: UniverseGraphNodeKind
    let position: CGPoint
    let radius: CGFloat
    let hitRadius: CGFloat
    let isSelected: Bool
    let isContext: Bool
    let opacity: Double
}

struct UniverseGraphEdge: Identifiable, Equatable {
    let sourceID: String
    let targetID: String
    let source: CGPoint
    let target: CGPoint
    let category: ToolCategoryId
    let isEmphasized: Bool

    var id: String { "\(sourceID)->\(targetID)" }
}

struct UniverseGraphLayoutResult: Equatable {
    let nodes: [UniverseGraphNode]
    let edges: [UniverseGraphEdge]
}

enum UniverseGraphLayout {
    static func make(planets: [PlanetData], mode: UniverseMode, size: CGSize) -> UniverseGraphLayoutResult {
        guard !planets.isEmpty else {
            return UniverseGraphLayoutResult(nodes: [], edges: [])
        }

        // Large universes (e.g. the full sample seed) cannot fit inside one
        // phone screen without overlap. Grow the working area — and the ring /
        // tool spreads — with node count so the collision solver always has
        // room; the view lets the user pan/zoom across the larger canvas. Small
        // hand-built universes (<= baseline) keep spreadScale == 1, unchanged.
        let nodeTotal = planets.reduce(0) { $0 + $1.tools.count } + planets.count
        let spreadScale = max(1, (CGFloat(nodeTotal) / 18).squareRoot())
        let bounds = graphBounds(in: size, spreadScale: spreadScale)
        let corePlanet = planets.first { $0.id == .core }
        let branches = planets.filter { $0.id != .core }
        let corePoint = CGPoint(x: bounds.midX, y: bounds.minY + bounds.height * 0.42)
        var drafts: [NodeDraft] = []
        var edgeSeeds: [(sourceID: String, targetID: String, category: ToolCategoryId)] = []

        if let corePlanet {
            drafts.append(
                NodeDraft(
                    id: nodeID(forCategory: .core),
                    title: corePlanet.title,
                    subtitle: "Core",
                    category: .core,
                    toolID: nil,
                    kind: .core,
                    position: corePoint,
                    initialPosition: corePoint,
                    radius: 46,
                    hitRadius: 68,
                    isPinned: true
                )
            )
            appendCoreToolDrafts(
                from: corePlanet,
                around: corePoint,
                into: &drafts,
                edgeSeeds: &edgeSeeds,
                bounds: bounds,
                spreadScale: spreadScale
            )
        }

        for (index, planet) in branches.enumerated() {
            let categoryPoint = categoryPoint(
                index: index,
                count: branches.count,
                center: corePoint,
                bounds: bounds,
                spreadScale: spreadScale
            )
            let categoryID = nodeID(forCategory: planet.id)
            drafts.append(
                NodeDraft(
                    id: categoryID,
                    title: planet.title,
                    subtitle: "\(planet.toolCount) tools",
                    category: planet.id,
                    toolID: nil,
                    kind: .category,
                    position: categoryPoint,
                    initialPosition: categoryPoint,
                    radius: 34,
                    hitRadius: 56,
                    isPinned: false
                )
            )
            if corePlanet != nil {
                edgeSeeds.append((nodeID(forCategory: .core), categoryID, planet.id))
            }
            appendToolDrafts(
                from: planet,
                categoryPoint: categoryPoint,
                corePoint: corePoint,
                into: &drafts,
                edgeSeeds: &edgeSeeds,
                bounds: bounds,
                spreadScale: spreadScale
            )
        }

        resolveCollisions(in: &drafts, bounds: bounds)

        let selectedToolID = mode.selectedToolID
        let nodes = drafts.map { draft in
            let isToolSelected = draft.toolID != nil && draft.toolID == selectedToolID
            let isCategorySelected = draft.toolID == nil && draft.category == mode.focusedCategory && selectedToolID == nil
            let isContext = draft.category == mode.focusedCategory
            let opacity = opacity(for: draft, mode: mode, selectedToolID: selectedToolID)
            return UniverseGraphNode(
                id: draft.id,
                title: draft.title,
                subtitle: draft.subtitle,
                category: draft.category,
                toolID: draft.toolID,
                kind: draft.kind,
                position: draft.position,
                radius: draft.radius,
                hitRadius: draft.hitRadius,
                isSelected: isToolSelected || isCategorySelected,
                isContext: isContext,
                opacity: opacity
            )
        }

        let nodePositions = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0.position) })
        let edges = edgeSeeds.compactMap { seed -> UniverseGraphEdge? in
            guard let source = nodePositions[seed.sourceID],
                  let target = nodePositions[seed.targetID] else { return nil }
            return UniverseGraphEdge(
                sourceID: seed.sourceID,
                targetID: seed.targetID,
                source: source,
                target: target,
                category: seed.category,
                isEmphasized: seed.category == mode.focusedCategory
            )
        }

        return UniverseGraphLayoutResult(nodes: nodes, edges: edges)
    }

    private static func graphBounds(in size: CGSize, spreadScale: CGFloat = 1) -> CGRect {
        let width = max(size.width, 320)
        let height = max(size.height, 560)
        let horizontalInset = max(24, min(width * 0.07, 42))
        let topInset = max(76, min(height * 0.12, 112))
        let lowerLimit = height - max(214, min(height * 0.26, 286))
        let graphHeight = max(330, lowerLimit - topInset)
        let baseWidth = width - horizontalInset * 2
        let scaledWidth = baseWidth * spreadScale
        let scaledHeight = graphHeight * spreadScale
        // Grow the rect symmetrically around the base centre so the core stays
        // roughly centred while extra room opens up beyond the screen edges.
        return CGRect(
            x: horizontalInset - (scaledWidth - baseWidth) / 2,
            y: topInset - (scaledHeight - graphHeight) / 2,
            width: scaledWidth,
            height: scaledHeight
        )
    }

    private static func nodeID(forCategory category: ToolCategoryId) -> String {
        "category:\(category.rawValue)"
    }

    private static func nodeID(forTool tool: Tool) -> String {
        "tool:\(tool.id)"
    }

    private static func categoryPoint(index: Int, count: Int, center: CGPoint, bounds: CGRect, spreadScale: CGFloat = 1) -> CGPoint {
        guard count > 0 else { return center }
        let step = (2 * CGFloat.pi) / CGFloat(count)
        let angle = -CGFloat.pi / 2 + CGFloat(index) * step
        let radiusX = min(bounds.width * 0.39, 168 * spreadScale)
        let radiusY = min(bounds.height * 0.34, 142 * spreadScale)
        return CGPoint(
            x: center.x + cos(angle) * radiusX,
            y: center.y + sin(angle) * radiusY
        )
    }

    private static func appendCoreToolDrafts(
        from planet: PlanetData,
        around corePoint: CGPoint,
        into drafts: inout [NodeDraft],
        edgeSeeds: inout [(sourceID: String, targetID: String, category: ToolCategoryId)],
        bounds: CGRect,
        spreadScale: CGFloat = 1
    ) {
        let visibleTools = planet.tools.filter { $0.id != PlanetData.centralCoreToolID }
        for (index, tool) in visibleTools.enumerated() {
            let angle = CGFloat.pi / 2 + CGFloat(index) * 0.9
            let point = clamp(
                CGPoint(
                    x: corePoint.x + cos(angle) * 82 * spreadScale,
                    y: corePoint.y + sin(angle) * 72 * spreadScale
                ),
                radius: 48,
                bounds: bounds
            )
            let id = nodeID(forTool: tool)
            drafts.append(toolDraft(for: tool, position: point, category: .core))
            edgeSeeds.append((nodeID(forCategory: .core), id, .core))
        }
    }

    private static func appendToolDrafts(
        from planet: PlanetData,
        categoryPoint: CGPoint,
        corePoint: CGPoint,
        into drafts: inout [NodeDraft],
        edgeSeeds: inout [(sourceID: String, targetID: String, category: ToolCategoryId)],
        bounds: CGRect,
        spreadScale: CGFloat = 1
    ) {
        let direction = normalized(CGVector(dx: categoryPoint.x - corePoint.x, dy: categoryPoint.y - corePoint.y))
        let perpendicular = CGVector(dx: -direction.dy, dy: direction.dx)
        let categoryID = nodeID(forCategory: planet.id)
        let count = max(planet.tools.count, 1)

        for (index, tool) in planet.tools.enumerated() {
            let row = CGFloat(index / 4)
            let rowCount = CGFloat(min(4, max(count - index / 4 * 4, 1)))
            let slot = CGFloat(index % 4) - (rowCount - 1) / 2
            let distance: CGFloat = (72 + row * 38) * spreadScale
            let spread: CGFloat = (count <= 2 ? 48 : 42) * spreadScale
            let point = clamp(
                CGPoint(
                    x: categoryPoint.x + direction.dx * distance + perpendicular.dx * slot * spread,
                    y: categoryPoint.y + direction.dy * distance + perpendicular.dy * slot * spread
                ),
                radius: 44,
                bounds: bounds
            )
            let id = nodeID(forTool: tool)
            drafts.append(toolDraft(for: tool, position: point, category: planet.id))
            edgeSeeds.append((categoryID, id, planet.id))
        }
    }

    private static func toolDraft(for tool: Tool, position: CGPoint, category: ToolCategoryId) -> NodeDraft {
        NodeDraft(
            id: nodeID(forTool: tool),
            title: tool.name,
            subtitle: stageLabel(tool.stage),
            category: category,
            toolID: tool.id,
            kind: .tool,
            position: position,
            initialPosition: position,
            radius: 20,
            hitRadius: 42,
            isPinned: false
        )
    }

    private static func stageLabel(_ stage: WorkflowStageId) -> String {
        switch stage {
        case .research: return "Research"
        case .planning: return "Plan"
        case .execution: return "Build"
        case .approval: return "Ship"
        case .review: return "Review"
        }
    }

    private static func resolveCollisions(in drafts: inout [NodeDraft], bounds: CGRect) {
        guard drafts.count > 1 else { return }
        for _ in 0..<90 {
            for i in drafts.indices {
                for j in drafts.indices where j > i {
                    let delta = CGVector(
                        dx: drafts[j].position.x - drafts[i].position.x,
                        dy: drafts[j].position.y - drafts[i].position.y
                    )
                    var distance = sqrt(delta.dx * delta.dx + delta.dy * delta.dy)
                    var direction = normalized(delta)
                    if distance < 0.001 {
                        let angle = CGFloat(i + j + 1) * 1.618
                        direction = CGVector(dx: cos(angle), dy: sin(angle))
                        distance = 0.001
                    }

                    let minimum = drafts[i].hitRadius + drafts[j].hitRadius + 6
                    guard distance < minimum else { continue }
                    let push = (minimum - distance) * 0.5

                    if drafts[i].isPinned {
                        drafts[j].position.x += direction.dx * push * 2
                        drafts[j].position.y += direction.dy * push * 2
                    } else if drafts[j].isPinned {
                        drafts[i].position.x -= direction.dx * push * 2
                        drafts[i].position.y -= direction.dy * push * 2
                    } else {
                        drafts[i].position.x -= direction.dx * push
                        drafts[i].position.y -= direction.dy * push
                        drafts[j].position.x += direction.dx * push
                        drafts[j].position.y += direction.dy * push
                    }
                }
            }

            for index in drafts.indices where !drafts[index].isPinned {
                drafts[index].position.x += (drafts[index].initialPosition.x - drafts[index].position.x) * 0.018
                drafts[index].position.y += (drafts[index].initialPosition.y - drafts[index].position.y) * 0.018
                drafts[index].position = clamp(drafts[index].position, radius: drafts[index].hitRadius, bounds: bounds)
            }
        }

        // A final visual-radius pass matters on narrow iPhones where the
        // larger label hit-radii can be impossible to fully satisfy near the
        // bounds, but visible circles still must never touch or overlap.
        for _ in 0..<32 {
            for i in drafts.indices {
                for j in drafts.indices where j > i {
                    let delta = CGVector(
                        dx: drafts[j].position.x - drafts[i].position.x,
                        dy: drafts[j].position.y - drafts[i].position.y
                    )
                    var distance = sqrt(delta.dx * delta.dx + delta.dy * delta.dy)
                    var direction = normalized(delta)
                    if distance < 0.001 {
                        let angle = CGFloat(i + j + 1) * 1.618
                        direction = CGVector(dx: cos(angle), dy: sin(angle))
                        distance = 0.001
                    }

                    let minimum = drafts[i].radius + drafts[j].radius + 8
                    guard distance < minimum else { continue }
                    let push = (minimum - distance) * 0.5

                    if drafts[i].isPinned {
                        drafts[j].position.x += direction.dx * push * 2
                        drafts[j].position.y += direction.dy * push * 2
                    } else if drafts[j].isPinned {
                        drafts[i].position.x -= direction.dx * push * 2
                        drafts[i].position.y -= direction.dy * push * 2
                    } else {
                        drafts[i].position.x -= direction.dx * push
                        drafts[i].position.y -= direction.dy * push
                        drafts[j].position.x += direction.dx * push
                        drafts[j].position.y += direction.dy * push
                    }
                }
            }

            for index in drafts.indices where !drafts[index].isPinned {
                drafts[index].position = clamp(drafts[index].position, radius: drafts[index].radius + 4, bounds: bounds)
            }
        }
    }

    private static func normalized(_ vector: CGVector) -> CGVector {
        let length = sqrt(vector.dx * vector.dx + vector.dy * vector.dy)
        guard length > 0.001 else { return CGVector(dx: 1, dy: 0) }
        return CGVector(dx: vector.dx / length, dy: vector.dy / length)
    }

    private static func clamp(_ point: CGPoint, radius: CGFloat, bounds: CGRect) -> CGPoint {
        CGPoint(
            x: min(max(point.x, bounds.minX + radius), bounds.maxX - radius),
            y: min(max(point.y, bounds.minY + radius), bounds.maxY - radius)
        )
    }

    private static func opacity(for draft: NodeDraft, mode: UniverseMode, selectedToolID: String?) -> Double {
        if mode.isDetailOpen { return draft.category == mode.focusedCategory ? 0.58 : 0.28 }
        if mode.isChatOpen { return draft.category == mode.focusedCategory ? 0.8 : 0.48 }
        if selectedToolID == nil, mode.focusedCategory == .core { return draft.category == .core ? 1 : 0.86 }
        if draft.category == mode.focusedCategory { return 1 }
        return 0.42
    }
}

private struct NodeDraft {
    let id: String
    let title: String
    let subtitle: String
    let category: ToolCategoryId
    let toolID: String?
    let kind: UniverseGraphNodeKind
    var position: CGPoint
    let initialPosition: CGPoint
    let radius: CGFloat
    let hitRadius: CGFloat
    let isPinned: Bool
}

struct UniverseGraphView: View {
    let planets: [PlanetData]
    let mode: UniverseMode
    let onPlanetTap: @MainActor @Sendable (ToolCategoryId) -> Void
    let onToolTap: @MainActor @Sendable (String) -> Void
    let onEmptyTap: @MainActor @Sendable () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @GestureState private var dragTranslation: CGSize = .zero
    @GestureState private var magnification: CGFloat = 1
    @State private var pan: CGSize = .zero
    @State private var scale: CGFloat = 1

    private var effectiveReduceMotion: Bool {
        reduceMotion || ProcessInfo.processInfo.arguments.contains("-uitestStatic")
    }

    var body: some View {
        GeometryReader { proxy in
            let layout = UniverseGraphLayout.make(planets: planets, mode: mode, size: proxy.size)
            ZStack {
                background
                    .onTapGesture {
                        guard mode.allowsMapGestures || mode.isChatOpen else { return }
                        onEmptyTap()
                    }

                graphContent(layout: layout)
            }
            .scaleEffect(currentScale, anchor: .center)
            .offset(currentPan)
            .contentShape(Rectangle())
            .simultaneousGesture(dragGesture)
            .simultaneousGesture(pinchGesture)
            .opacity(mode.mapOpacity)
            .blur(radius: CGFloat(mode.mapBlurRadius))
            .brandAnimation(BrandMotion.flow, value: mode.signature)
            .brandAnimation(BrandMotion.flow, value: planets.map(\.toolCount))
        }
    }

    private var currentScale: CGFloat {
        min(max(scale * magnification, 0.5), 1.55)
    }

    private var currentPan: CGSize {
        CGSize(width: pan.width + dragTranslation.width, height: pan.height + dragTranslation.height)
    }

    private var background: some View {
        ZStack {
            BrandColor.void
            RadialGradient(
                colors: [
                    BrandColor.cyan.opacity(0.16),
                    BrandColor.violet.opacity(0.08),
                    .clear
                ],
                center: .center,
                startRadius: 20,
                endRadius: 360
            )
            Color.white.opacity(0.018)
        }
        .ignoresSafeArea()
    }

    private func graphContent(layout: UniverseGraphLayoutResult) -> some View {
        ZStack {
            edgeLayer(edges: layout.edges)

            ForEach(layout.nodes) { node in
                GraphNodeButton(
                    node: node,
                    reduceMotion: effectiveReduceMotion,
                    action: {
                        guard mode.allowsMapGestures else { return }
                        switch node.kind {
                        case .core, .category:
                            onPlanetTap(node.category)
                        case .tool:
                            if let toolID = node.toolID {
                                onToolTap(toolID)
                            }
                        }
                    }
                )
                .position(node.position)
                .zIndex(node.isSelected ? 20 : node.isContext ? 10 : Double(node.radius))
            }
        }
    }

    @ViewBuilder
    private func edgeLayer(edges: [UniverseGraphEdge]) -> some View {
        if effectiveReduceMotion || mode.pausesAmbientMotion {
            edgeCanvas(edges: edges, phase: 0)
        } else {
            TimelineView(.animation) { timeline in
                edgeCanvas(
                    edges: edges,
                    phase: timeline.date.timeIntervalSinceReferenceDate
                )
            }
        }
    }

    private func edgeCanvas(edges: [UniverseGraphEdge], phase: TimeInterval) -> some View {
        Canvas { context, _ in
            drawEdges(edges, context: &context, phase: phase)
        }
        .allowsHitTesting(false)
    }

    private func drawEdges(_ edges: [UniverseGraphEdge], context: inout GraphicsContext, phase: TimeInterval) {
        for edge in edges {
            let color = UniverseSeed.category(edge.category).color.swiftUIColor
            let vector = CGVector(dx: edge.target.x - edge.source.x, dy: edge.target.y - edge.source.y)
            let distance = max(sqrt(vector.dx * vector.dx + vector.dy * vector.dy), 1)
            let normal = CGVector(dx: -vector.dy / distance, dy: vector.dx / distance)
            let wobble = effectiveReduceMotion ? 0 : sin(phase * 0.55 + Double(edge.targetID.hashValue % 17)) * 8
            let control = CGPoint(
                x: (edge.source.x + edge.target.x) / 2 + normal.dx * (18 + wobble),
                y: (edge.source.y + edge.target.y) / 2 + normal.dy * (18 + wobble)
            )

            var path = Path()
            path.move(to: edge.source)
            path.addQuadCurve(to: edge.target, control: control)

            let opacity = edge.isEmphasized ? 0.52 : 0.18
            let width: CGFloat = edge.isEmphasized ? 1.8 : 1.05
            context.stroke(path, with: .color(color.opacity(opacity)), lineWidth: width)
        }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .updating($dragTranslation) { value, state, _ in
                guard mode.allowsMapGestures else { return }
                state = value.translation
            }
            .onEnded { value in
                guard mode.allowsMapGestures else { return }
                pan.width = min(max(pan.width + value.translation.width, -120), 120)
                pan.height = min(max(pan.height + value.translation.height, -92), 92)
            }
    }

    private var pinchGesture: some Gesture {
        MagnifyGesture()
            .updating($magnification) { value, state, _ in
                guard mode.allowsMapGestures else { return }
                state = value.magnification
            }
            .onEnded { value in
                guard mode.allowsMapGestures else { return }
                scale = min(max(scale * value.magnification, 0.5), 1.55)
            }
    }
}

private struct GraphNodeButton: View {
    let node: UniverseGraphNode
    let reduceMotion: Bool
    let action: () -> Void

    private var color: Color {
        UniverseSeed.category(node.category).color.swiftUIColor
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                ZStack {
                    Circle()
                        .fill(color.opacity(node.kind == .tool ? 0.18 : 0.24))
                        .frame(width: node.radius * 2.55, height: node.radius * 2.55)
                        .blur(radius: node.isSelected ? 4 : 8)
                        .opacity(node.isSelected ? 0.72 : 0.42)

                    Circle()
                        .fill(.black.opacity(0.34))
                        .overlay {
                            Circle()
                                .stroke(color.opacity(node.isSelected ? 0.95 : 0.42), lineWidth: node.isSelected ? 2.4 : 1.1)
                        }
                        .frame(width: node.radius * 2, height: node.radius * 2)

                    Circle()
                        .fill(color)
                        .frame(width: innerDotSize, height: innerDotSize)
                        .shadow(color: color.opacity(node.isSelected ? 0.78 : 0.36), radius: node.isSelected ? 12 : 6)

                    if node.kind != .tool {
                        Image(systemName: node.kind == .core ? "sparkles" : "circle.grid.cross")
                            .font(.system(size: node.kind == .core ? 16 : 13, weight: .bold))
                            .foregroundStyle(.black.opacity(0.72))
                    }
                }
                .scaleEffect(node.isSelected && !reduceMotion ? 1.08 : 1)

                VStack(spacing: 1) {
                    Text(node.title)
                        .font(labelFont)
                        .foregroundStyle(.white.opacity(node.opacity))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    Text(node.subtitle)
                        .font(.system(size: node.kind == .tool ? 8 : 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(BrandColor.textMuted.opacity(node.opacity))
                        .lineLimit(1)
                }
                .frame(width: labelWidth)
            }
            .opacity(node.opacity)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle(pressedScale: 0.94, haptic: nil, pressedOpacity: 0.92))
        .accessibilityLabel(accessibilityLabel)
    }

    private var innerDotSize: CGFloat {
        switch node.kind {
        case .core: return 18
        case .category: return 13
        case .tool: return 8
        }
    }

    private var labelFont: Font {
        switch node.kind {
        case .core: return .system(size: 13, weight: .bold, design: .rounded)
        case .category: return .system(size: 12, weight: .bold, design: .rounded)
        case .tool: return .system(size: 10, weight: .semibold, design: .rounded)
        }
    }

    private var labelWidth: CGFloat {
        switch node.kind {
        case .core: return 104
        case .category: return 92
        case .tool: return 78
        }
    }

    private var accessibilityLabel: String {
        switch node.kind {
        case .core:
            return "Core node, \(node.title)"
        case .category:
            return "Category node, \(node.title), \(node.subtitle)"
        case .tool:
            return "Tool node, \(node.title)"
        }
    }
}
