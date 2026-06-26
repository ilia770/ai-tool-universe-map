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
    let showsLabel: Bool
    let opacity: Double
}

struct UniverseGraphEdge: Identifiable, Equatable {
    let sourceID: String
    let targetID: String
    let source: CGPoint
    let target: CGPoint
    let sourceRadius: CGFloat
    let targetRadius: CGFloat
    let category: ToolCategoryId
    let isEmphasized: Bool

    var id: String { "\(sourceID)->\(targetID)" }

    func anchoredEndpoints(inset: CGFloat = 2) -> (source: CGPoint, target: CGPoint) {
        let vector = CGVector(dx: target.x - source.x, dy: target.y - source.y)
        let distance = max(sqrt(vector.dx * vector.dx + vector.dy * vector.dy), 1)
        let direction = CGVector(dx: vector.dx / distance, dy: vector.dy / distance)
        return (
            CGPoint(
                x: source.x + direction.dx * (sourceRadius + inset),
                y: source.y + direction.dy * (sourceRadius + inset)
            ),
            CGPoint(
                x: target.x - direction.dx * (targetRadius + inset),
                y: target.y - direction.dy * (targetRadius + inset)
            )
        )
    }
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

        // Progressive disclosure: tool nodes are emitted only for the focused
        // category, matching the 3D scene's satellite reveal (UniverseMode
        // .showsToolLabels / .showsSatellites are both false in overview). The
        // overview is therefore just core + categories — a clean hub-and-spoke
        // that fits one screen — and the working area only has to grow with the
        // nodes actually drawn, never the full ~50-tool seed.
        let showsTools = mode.showsToolLabels
        let focusedCategory = mode.focusedCategory
        let focusedToolCount = showsTools
            ? (planets.first { $0.id == focusedCategory }?.tools.count ?? 0)
            : 0
        let nodeTotal = planets.count + focusedToolCount
        let spreadScale = max(1, (CGFloat(nodeTotal) / 18).squareRoot())
        let bounds = graphBounds(in: size, spreadScale: spreadScale)
        let corePlanet = planets.first { $0.id == .core }
        let branches = planets.filter { $0.id != .core }
        let corePoint = CGPoint(x: bounds.midX, y: bounds.minY + bounds.height * 0.46)
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
            if showsTools && focusedCategory == .core {
                appendCoreToolDrafts(
                    from: corePlanet,
                    around: corePoint,
                    into: &drafts,
                    edgeSeeds: &edgeSeeds,
                    bounds: bounds,
                    spreadScale: spreadScale
                )
            }
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
                    subtitle: Pluralize.count(planet.toolCount, "tool"),
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
            if showsTools && focusedCategory == planet.id {
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
        }

        resolveCollisions(in: &drafts, bounds: bounds)

        let selectedToolID = mode.selectedToolID
        let nodes = drafts.map { draft in
            let isToolSelected = draft.toolID != nil && draft.toolID == selectedToolID
            let isCategorySelected = draft.toolID == nil && draft.category == mode.focusedCategory && selectedToolID == nil
            let isContext = draft.category == mode.focusedCategory
            let opacity = opacity(for: draft, mode: mode, selectedToolID: selectedToolID)
            // Label-culling contract: the collision solver only guarantees that
            // node *circles* never overlap (a screen cannot pack ~53 tool labels
            // without collision). So core and category labels — few, always
            // useful for orientation — always render, but a *tool* label only
            // renders when that tool is selected or lives in the focused
            // category (context). Every other tool node is a bare circle, so no
            // unfocused tool labels can overlap.
            let showsLabel = draft.kind != .tool
                || isToolSelected
                || isContext
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
                showsLabel: showsLabel,
                opacity: opacity
            )
        }

        let nodesByID = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
        let edges = edgeSeeds.compactMap { seed -> UniverseGraphEdge? in
            guard let source = nodesByID[seed.sourceID],
                  let target = nodesByID[seed.targetID] else { return nil }
            return UniverseGraphEdge(
                sourceID: seed.sourceID,
                targetID: seed.targetID,
                source: source.position,
                target: target.position,
                sourceRadius: source.radius,
                targetRadius: target.radius,
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
        // Reserve enough top room for the route pill + render-mode chrome so the
        // overview ring (which is not auto-panned) never tucks its top category
        // under the controls. Focus modes get their own larger clearance via
        // UniverseGraphViewport.focusPadding.
        let topInset = max(108, min(height * 0.16, 150))
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
        let angle: CGFloat
        if count == 2 {
            // Two-branch universes otherwise stack into a vertical debug-looking
            // schematic. Bias them to balanced upper diagonals so branch -> tool
            // relations read as a map immediately.
            angle = index == 0 ? -CGFloat.pi * 0.80 : -CGFloat.pi * 0.20
        } else {
            let step = (2 * CGFloat.pi) / CGFloat(count)
            angle = -CGFloat.pi / 2 + CGFloat(index) * step
        }
        let radiusX = min(bounds.width * 0.41, 172 * spreadScale)
        let radiusY = min(bounds.height * 0.36, 156 * spreadScale)
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
        let categoryID = nodeID(forCategory: planet.id)
        let count = max(planet.tools.count, 1)

        // Focused tools sit on an even ring AROUND their category, not a tall
        // grid marching away from the core. A symmetric ring is compact (so the
        // auto-pan can centre the whole cluster inside the tappable band without
        // clipping under the top chrome) and spaces labels evenly instead of
        // colliding them in dense rows. The ring grows with count so arc spacing
        // stays roughly constant. For large branches it splits into two rings.
        let awayAngle = atan2(categoryPoint.y - corePoint.y, categoryPoint.x - corePoint.x)
        let useTwoRings = count > 7
        let innerCount = useTwoRings ? Int((Double(count) / 2).rounded(.up)) : count
        let outerCount = count - innerCount
        let innerRadius = (max(80, CGFloat(min(count, innerCount)) * 15)) * spreadScale
        let outerRadius = innerRadius + 56 * spreadScale

        for (index, tool) in planet.tools.enumerated() {
            let onInner = index < innerCount
            let ringCount = onInner ? innerCount : max(outerCount, 1)
            let ringIndex = onInner ? index : index - innerCount
            let ringRadius = onInner ? innerRadius : outerRadius
            // Stagger the outer ring half a slot so outer nodes nest between
            // inner ones instead of stacking radially.
            let stagger = onInner ? 0 : CGFloat.pi / CGFloat(max(ringCount, 1))
            let angle = awayAngle + stagger + (2 * .pi) * CGFloat(ringIndex) / CGFloat(max(ringCount, 1))
            let point = clamp(
                CGPoint(
                    x: categoryPoint.x + cos(angle) * ringRadius,
                    y: categoryPoint.y + sin(angle) * ringRadius
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

enum UniverseGraphViewport {
    static func focusPan(
        layout: UniverseGraphLayoutResult,
        mode: UniverseMode,
        viewport: CGSize,
        scale: CGFloat
    ) -> CGSize {
        guard let focusRect = focusRect(layout: layout, mode: mode) else { return .zero }

        let projected = project(rect: focusRect, viewport: viewport, scale: scale, pan: .zero)
        let padding = focusPadding(for: viewport)
        let leftLimit = padding.leading
        let rightLimit = max(leftLimit + 80, viewport.width - padding.trailing)
        let topLimit = padding.top
        let bottomLimit = max(topLimit + 80, viewport.height - padding.bottom)

        var proposed = CGSize.zero
        let availableWidth = rightLimit - leftLimit
        if projected.width > availableWidth {
            proposed.width = (leftLimit + rightLimit) / 2 - projected.midX
        } else if projected.minX < leftLimit {
            proposed.width = leftLimit - projected.minX
        } else if projected.maxX > rightLimit {
            proposed.width = rightLimit - projected.maxX
        }

        let availableHeight = bottomLimit - topLimit
        if projected.height > availableHeight {
            proposed.height = (topLimit + bottomLimit) / 2 - projected.midY
        } else if projected.minY < topLimit {
            proposed.height = topLimit - projected.minY
        } else if projected.maxY > bottomLimit {
            proposed.height = bottomLimit - projected.maxY
        }

        return clampedPan(proposed, layout: layout, viewport: viewport, scale: scale)
    }

    static func clampedPan(
        _ proposed: CGSize,
        layout: UniverseGraphLayoutResult,
        viewport: CGSize,
        scale: CGFloat
    ) -> CGSize {
        let limit = panLimit(layout: layout, viewport: viewport, scale: scale)
        return CGSize(
            width: min(max(proposed.width, -limit.width), limit.width),
            height: min(max(proposed.height, -limit.height), limit.height)
        )
    }

    static func visiblePan(
        storedPan: CGSize,
        focusPan: CGSize,
        layout: UniverseGraphLayoutResult,
        viewport: CGSize,
        scale: CGFloat
    ) -> CGSize {
        clampedPan(
            CGSize(width: focusPan.width + storedPan.width, height: focusPan.height + storedPan.height),
            layout: layout,
            viewport: viewport,
            scale: scale
        )
    }

    static func storedPan(
        forVisiblePan visiblePan: CGSize,
        focusPan: CGSize,
        layout: UniverseGraphLayoutResult,
        viewport: CGSize,
        scale: CGFloat
    ) -> CGSize {
        // `panLimit` is a visible-screen constraint. Stored user pan is
        // relative to auto-focus pan, so clamping it independently can distort
        // the next `focusPan + storedPan` round-trip.
        return CGSize(
            width: visiblePan.width - focusPan.width,
            height: visiblePan.height - focusPan.height
        )
    }

    static func projectedFrame(
        for node: UniverseGraphNode,
        viewport: CGSize,
        scale: CGFloat,
        pan: CGSize
    ) -> CGRect {
        project(
            rect: CGRect(
                x: node.position.x - node.hitRadius,
                y: node.position.y - node.hitRadius,
                width: node.hitRadius * 2,
                height: node.hitRadius * 2
            ),
            viewport: viewport,
            scale: scale,
            pan: pan
        )
    }

    private static func focusRect(layout: UniverseGraphLayoutResult, mode: UniverseMode) -> CGRect? {
        let focusNodes: [UniverseGraphNode]
        switch mode {
        case .overview, .detail, .chatOpen:
            return nil
        case .branchFocus(let category):
            let toolNodes = layout.nodes.filter { $0.kind == .tool && $0.category == category }
            focusNodes = toolNodes.isEmpty
                ? layout.nodes.filter { $0.category == category }
                : toolNodes
        case .toolSelected(let category, let toolID):
            focusNodes = layout.nodes.filter { node in
                (node.kind == .category && node.category == category) || node.toolID == toolID
            }
        }

        return focusNodes
            .map { node in
                CGRect(
                    x: node.position.x - node.hitRadius,
                    y: node.position.y - node.hitRadius,
                    width: node.hitRadius * 2,
                    height: node.hitRadius * 2
                )
            }
            .reduce(nil) { partial, rect in
                partial?.union(rect) ?? rect
            }
    }

    private static func focusPadding(for viewport: CGSize) -> EdgeInsets {
        EdgeInsets(
            top: min(max(viewport.height * 0.23, 196), 228),
            leading: min(max(viewport.width * 0.15, 56), 78),
            bottom: min(max(viewport.height * 0.27, 220), 270),
            trailing: min(max(viewport.width * 0.12, 48), 72)
        )
    }

    private static func project(rect: CGRect, viewport: CGSize, scale: CGFloat, pan: CGSize) -> CGRect {
        let center = CGPoint(x: viewport.width / 2, y: viewport.height / 2)
        return CGRect(
            x: center.x + (rect.minX - center.x) * scale + pan.width,
            y: center.y + (rect.minY - center.y) * scale + pan.height,
            width: rect.width * scale,
            height: rect.height * scale
        )
    }

    private static func panLimit(
        layout: UniverseGraphLayoutResult,
        viewport: CGSize,
        scale: CGFloat
    ) -> CGSize {
        guard !layout.nodes.isEmpty else { return .zero }

        let minX = layout.nodes.map { $0.position.x - $0.hitRadius }.min() ?? 0
        let maxX = layout.nodes.map { $0.position.x + $0.hitRadius }.max() ?? viewport.width
        let minY = layout.nodes.map { $0.position.y - $0.hitRadius }.min() ?? 0
        let maxY = layout.nodes.map { $0.position.y + $0.hitRadius }.max() ?? viewport.height

        let center = CGPoint(x: viewport.width / 2, y: viewport.height / 2)
        let scaledMinX = center.x + (minX - center.x) * scale
        let scaledMaxX = center.x + (maxX - center.x) * scale
        let scaledMinY = center.y + (minY - center.y) * scale
        let scaledMaxY = center.y + (maxY - center.y) * scale
        let edgePadding: CGFloat = 48

        let horizontalNeed = max(
            max(0, edgePadding - scaledMinX),
            max(0, scaledMaxX - viewport.width + edgePadding)
        )
        let verticalNeed = max(
            max(0, edgePadding - scaledMinY),
            max(0, scaledMaxY - viewport.height + edgePadding)
        )
        let focusChromeClearance = focusPadding(for: viewport).top + edgePadding

        return CGSize(
            width: max(120, horizontalNeed),
            height: max(focusChromeClearance, verticalNeed)
        )
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
            let focusPan = UniverseGraphViewport.focusPan(
                layout: layout,
                mode: mode,
                viewport: proxy.size,
                scale: currentScale
            )
            let visiblePan = UniverseGraphViewport.visiblePan(
                storedPan: currentPan,
                focusPan: focusPan,
                layout: layout,
                viewport: proxy.size,
                scale: currentScale
            )
            ZStack {
                background
                    .onTapGesture {
                        guard mode.allowsMapGestures || mode.isChatOpen else { return }
                        onEmptyTap()
                    }

                graphContent(layout: layout)
                    .scaleEffect(currentScale, anchor: .center)
                    .offset(visiblePan)
            }
            .contentShape(Rectangle())
            .simultaneousGesture(dragGesture(layout: layout, viewport: proxy.size))
            .simultaneousGesture(pinchGesture(layout: layout, viewport: proxy.size))
            .opacity(mode.mapOpacity)
            .blur(radius: CGFloat(mode.mapBlurRadius))
            .brandAnimation(BrandMotion.flow, value: mode.signature)
            .brandAnimation(BrandMotion.flow, value: planets.map(\.toolCount))
            .onChange(of: mode.signature) { _, _ in
                pan = .zero
            }
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
                .background { toolFlightAnchor(for: node) }
            }
        }
    }

    /// Publishes the selected tool node's on-screen frame (in the shared flight
    /// coordinate space) so the shell can land a card→planet ghost on it. Only
    /// the selected tool reports — the shell rejects any other tool's frame.
    @ViewBuilder
    private func toolFlightAnchor(for node: UniverseGraphNode) -> some View {
        if let toolID = node.toolID, toolID == mode.selectedToolID {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: ToolFlightTargetPreferenceKey.self,
                    value: ToolFlightTarget(
                        toolID: toolID,
                        frame: proxy.frame(in: .named(RootShellCoordinateSpace.name))
                    )
                )
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
            let endpoints = edge.anchoredEndpoints()
            let vector = CGVector(dx: endpoints.target.x - endpoints.source.x, dy: endpoints.target.y - endpoints.source.y)
            let distance = max(sqrt(vector.dx * vector.dx + vector.dy * vector.dy), 1)
            let normal = CGVector(dx: -vector.dy / distance, dy: vector.dx / distance)
            let wobble = effectiveReduceMotion ? 0 : sin(phase * 0.55 + Double(edge.targetID.hashValue % 17)) * 5
            let bend = min(max(distance * 0.16, 16), 34)
            let control = CGPoint(
                x: (endpoints.source.x + endpoints.target.x) / 2 + normal.dx * (bend + wobble),
                y: (endpoints.source.y + endpoints.target.y) / 2 + normal.dy * (bend + wobble)
            )

            var path = Path()
            path.move(to: endpoints.source)
            path.addQuadCurve(to: endpoints.target, control: control)

            // Spokes are the whole point of a hub-and-spoke map, so the resting
            // (non-emphasized) edge has to actually read against the dark field —
            // not the near-invisible hairline it was. Focused edges still pull
            // clearly ahead.
            let opacity = edge.isEmphasized ? 0.5 : 0.26
            let width: CGFloat = edge.isEmphasized ? 1.8 : 1.15
            context.stroke(path, with: .color(color.opacity(opacity)), lineWidth: width)
        }
    }

    private func dragGesture(layout: UniverseGraphLayoutResult, viewport: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .updating($dragTranslation) { value, state, _ in
                guard mode.allowsMapGestures else { return }
                state = value.translation
            }
            .onEnded { value in
                guard mode.allowsMapGestures else { return }
                let focusPan = UniverseGraphViewport.focusPan(
                    layout: layout,
                    mode: mode,
                    viewport: viewport,
                    scale: currentScale
                )
                let proposedVisiblePan = UniverseGraphViewport.visiblePan(
                    storedPan: CGSize(
                        width: pan.width + value.translation.width,
                        height: pan.height + value.translation.height
                    ),
                    focusPan: focusPan,
                    layout: layout,
                    viewport: viewport,
                    scale: currentScale
                )
                pan = UniverseGraphViewport.storedPan(
                    forVisiblePan: proposedVisiblePan,
                    focusPan: focusPan,
                    layout: layout,
                    viewport: viewport,
                    scale: currentScale
                )
            }
    }

    private func pinchGesture(layout: UniverseGraphLayoutResult, viewport: CGSize) -> some Gesture {
        MagnifyGesture()
            .updating($magnification) { value, state, _ in
                guard mode.allowsMapGestures else { return }
                state = value.magnification
            }
            .onEnded { value in
                guard mode.allowsMapGestures else { return }
                let previousScale = scale
                let previousFocusPan = UniverseGraphViewport.focusPan(
                    layout: layout,
                    mode: mode,
                    viewport: viewport,
                    scale: previousScale
                )
                let previousVisiblePan = UniverseGraphViewport.visiblePan(
                    storedPan: pan,
                    focusPan: previousFocusPan,
                    layout: layout,
                    viewport: viewport,
                    scale: previousScale
                )
                let nextScale = min(max(scale * value.magnification, 0.5), 1.55)
                let nextFocusPan = UniverseGraphViewport.focusPan(
                    layout: layout,
                    mode: mode,
                    viewport: viewport,
                    scale: nextScale
                )
                scale = nextScale
                let nextVisiblePan = UniverseGraphViewport.clampedPan(
                    previousVisiblePan,
                    layout: layout,
                    viewport: viewport,
                    scale: nextScale
                )
                pan = UniverseGraphViewport.storedPan(
                    forVisiblePan: nextVisiblePan,
                    focusPan: nextFocusPan,
                    layout: layout,
                    viewport: viewport,
                    scale: nextScale
                )
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
                    if node.isSelected {
                        Circle()
                            .stroke(.white.opacity(0.36), lineWidth: 8)
                            .frame(width: node.radius * 2 + 16, height: node.radius * 2 + 16)
                            .blur(radius: 5)
                            .opacity(0.72)
                    }

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

                    if node.kind == .tool {
                        Text(toolInitials)
                            .font(.system(size: node.isSelected ? 11 : 10, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white.opacity(node.isSelected ? 0.96 : 0.82))
                            .shadow(color: color.opacity(node.isSelected ? 0.72 : 0.34), radius: node.isSelected ? 10 : 5)
                    } else {
                        Image(systemName: node.kind == .core ? "sparkles" : "circle.hexagongrid.fill")
                            .font(.system(size: node.kind == .core ? 16 : 13, weight: .bold))
                            .foregroundStyle(.white.opacity(node.isSelected ? 0.94 : 0.82))
                            .shadow(color: color.opacity(node.isSelected ? 0.62 : 0.30), radius: node.isSelected ? 9 : 5)
                    }
                }
                .scaleEffect(node.isSelected && !reduceMotion ? 1.08 : 1)

                // Labels are culled for unfocused tool nodes (see the
                // label-culling contract in UniverseGraphLayout.make), so only
                // node circles are guaranteed not to overlap. Rendering the
                // label only when shown also keeps the bare circles compact.
                if node.showsLabel {
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
                    .padding(.horizontal, 7)
                    .padding(.vertical, node.kind == .tool ? 3 : 4)
                    .frame(width: labelWidth)
                    .background(.black.opacity(node.isSelected ? 0.36 : 0.24), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
            }
            .opacity(node.opacity)
            .frame(minWidth: node.hitRadius * 2, minHeight: node.hitRadius * 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle(pressedScale: 0.94, haptic: nil, pressedOpacity: 0.92))
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private var innerDotSize: CGFloat {
        switch node.kind {
        case .core: return 18
        case .category: return 13
        case .tool: return 8
        }
    }

    private var toolInitials: String {
        let words = node.title
            .split { !$0.isLetter && !$0.isNumber }
            .prefix(2)
            .compactMap(\.first)
        let initials = String(words).uppercased()
        return initials.isEmpty ? "AI" : initials
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

    private var accessibilityIdentifier: String {
        switch node.kind {
        case .core:
            return "GraphNode.Core.\(node.id)"
        case .category:
            return "GraphNode.Category.\(node.category.rawValue)"
        case .tool:
            return "GraphNode.Tool.\(node.toolID ?? node.id)"
        }
    }
}
