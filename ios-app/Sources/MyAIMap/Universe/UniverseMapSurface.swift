import SwiftUI

private let universeStageOrder: [WorkflowStageId] = [
    .research,
    .planning,
    .execution,
    .approval,
    .review,
]

/// SwiftUI-first universe renderer.
///
/// RealityKit remains available in `UniverseView`, but the product surface must
/// never cold-start into a blank Metal layer. This view keeps the iOS app
/// inspectable and interactive while preserving the same category/tool model.
struct UniverseMapSurface: View {
    let selectedCategory: ToolCategoryId
    let selectedToolId: String
    let tools: [Tool]
    let visualizationStyle: VisualizationStyle
    let onCategorySelect: (ToolCategoryId) -> Void
    let onToolSelect: (String) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var orbitPhase: Double = 0
    @State private var settledOrbit: CGSize = .zero
    @State private var zoomScale: CGFloat = 1
    @State private var zoomGestureStart: CGFloat?
    @State private var isOrbitingSurface = false
    @GestureState private var activeOrbitDrag: CGSize = .zero

    private var selectedCategoryModel: ToolCategory {
        UniverseSeed.category(selectedCategory)
    }

    private var visibleCategories: [ToolCategory] {
        UniverseSeed.categories.filter { $0.id != .core }
    }

    private var selectedCategoryTools: [Tool] {
        tools.filter { $0.category == selectedCategory && $0.category != .core }
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let center = mapCenter(in: size)
            let orbit = currentOrbit(in: size)

            ZStack {
                background(in: size)
                universeField(in: size, center: center, orbit: orbit)

                ambientReadout(in: size)
            }
            .frame(width: size.width, height: size.height)
            .clipped()
            .contentShape(Rectangle())
            .highPriorityGesture(surfaceOrbitGesture(in: size), including: .all)
            .simultaneousGesture(surfaceZoomGesture())
            .onAppear {
                BrandHaptics.prepare(.light, .medium)
                guard !reduceMotion else { return }
                orbitPhase = 0
                withAnimation(.linear(duration: animationDuration).repeatForever(autoreverses: false)) {
                    orbitPhase = 360
                }
            }
            .onChange(of: selectedCategory) { _, _ in
                flyToSelectedAnchor(in: size, resetZoom: false)
            }
            .onChange(of: selectedToolId) { _, _ in
                flyToSelectedAnchor(in: size, resetZoom: false)
            }
            .onChange(of: visualizationStyle) { _, _ in
                flyToSelectedAnchor(in: size, resetZoom: true)
            }
        }
        .ignoresSafeArea()
        .accessibilityElement(children: .contain)
    }

    private var animationDuration: Double {
        switch visualizationStyle {
        case .atlasOverlay: return 42
        case .kineticPockets: return 18
        case .force3D: return 20
        case .orbitalGlass: return 32
        }
    }

    private func universeField(in size: CGSize, center: CGPoint, orbit: CGSize) -> some View {
        ZStack {
            starField(in: size)
            linkLayer(in: size, center: center, orbit: orbit)
            orbitRings(in: size, center: center, orbit: orbit)
            if visualizationStyle == .force3D {
                stageTrajectory(in: size, center: center, orbit: orbit)
            }

            if selectedCategory == .core {
                overviewNodes(in: size, center: center, orbit: orbit)
            } else {
                pocketNodes(in: size, center: center, orbit: orbit)
            }
        }
        .scaleEffect(zoomScale * (isOrbitingSurface && !reduceMotion ? 1.012 : 1), anchor: .center)
        .shadow(
            color: selectedCategoryModel.color.swiftUIColor.opacity(isOrbitingSurface ? 0.16 : 0.08),
            radius: isOrbitingSurface ? 26 : 14,
            x: 0,
            y: isOrbitingSurface ? 14 : 8
        )
        .brandAnimation(BrandMotion.nudge, value: isOrbitingSurface)
        .brandAnimation(BrandMotion.flow, value: settledOrbit)
        .brandAnimation(BrandMotion.nudge, value: zoomScale)
    }

    private func background(in size: CGSize) -> some View {
        ZStack {
            LinearGradient(
                colors: [
                    selectedCategoryModel.color.swiftUIColor.opacity(visualizationStyle.backgroundGlow + 0.08),
                    Color(red: 0.02, green: 0.026, blue: 0.055),
                    BrandColor.void,
                    .black,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    selectedCategoryModel.glow.swiftUIColor.opacity(visualizationStyle.backgroundGlow + 0.16),
                    selectedCategoryModel.color.swiftUIColor.opacity(0.06),
                    .clear,
                ],
                center: .center,
                startRadius: 12,
                endRadius: min(size.width, size.height) * 0.62
            )
            .blendMode(.screen)

            if visualizationStyle == .force3D {
                RadialGradient(
                    colors: [
                        .white.opacity(0.12),
                        selectedCategoryModel.color.swiftUIColor.opacity(0.12),
                        .clear,
                    ],
                    center: .topTrailing,
                    startRadius: 12,
                    endRadius: min(size.width, size.height) * 0.86
                )
                .blendMode(.plusLighter)
            }
        }
    }

    private func starField(in size: CGSize) -> some View {
        ZStack {
            ForEach(0..<72, id: \.self) { index in
                let point = starPoint(index: index, size: size)
                let opacity = 0.12 + Double(index % 7) * (visualizationStyle == .force3D ? 0.046 : 0.035)
                let diameter = CGFloat(1 + index % 3)
                Circle()
                    .fill(index % 5 == 0 ? selectedCategoryModel.color.swiftUIColor.opacity(0.55) : .white.opacity(opacity))
                    .frame(width: diameter, height: diameter * (index % 11 == 0 && visualizationStyle == .force3D ? 1.8 : 1))
                    .blur(radius: index % 13 == 0 ? 0.4 : 0)
                    .position(point)
            }
        }
        .allowsHitTesting(false)
    }

    private func orbitRings(in size: CGSize, center: CGPoint, orbit: CGSize) -> some View {
        ZStack {
            ForEach(0..<4, id: \.self) { ring in
                let width = ringWidth(for: ring, in: size) * (0.94 + abs(orbit.pitchRatio) * 0.12)
                let height = width * ringAspect(for: ring)
                Ellipse()
                    .stroke(
                        selectedCategoryModel.color.swiftUIColor.opacity(ring == 0 ? 0.32 : 0.13),
                        style: StrokeStyle(lineWidth: ring == 0 ? 1.4 : 0.9, dash: ring == 0 || visualizationStyle == .force3D ? [] : [6, 9])
                    )
                    .frame(width: width, height: height)
                    .rotationEffect(.degrees(Double(ring * 11) + orbitPhase * (ring.isMultiple(of: 2) ? 0.08 : -0.05)))
                    .position(center)
            }
        }
        .allowsHitTesting(false)
    }

    private func linkLayer(in size: CGSize, center: CGPoint, orbit: CGSize) -> some View {
        Canvas { context, canvasSize in
            let canvasCenter = mapCenter(in: canvasSize)
            for category in visibleCategories {
                let destination = categoryProjection(category, in: canvasSize, center: canvasCenter, orbit: orbit).point
                var path = Path()
                path.move(to: canvasCenter)
                path.addLine(to: destination)
                let depth = categoryProjection(category, in: canvasSize, center: canvasCenter, orbit: orbit).depth
                let opacity = (category.id == selectedCategory || selectedCategory == .core ? 0.22 : 0.07) * Double(0.36 + depth * 0.64)
                context.stroke(path, with: .color(category.color.swiftUIColor.opacity(opacity)), lineWidth: 0.8)
            }

            guard selectedCategory != .core else { return }
            for (index, tool) in selectedCategoryTools.enumerated() {
                let destination = pocketToolProjection(tool: tool, index: index, count: selectedCategoryTools.count, in: canvasSize, center: canvasCenter, orbit: orbit).point
                var path = Path()
                path.move(to: canvasCenter)
                path.addLine(to: destination)
                context.stroke(path, with: .color(selectedCategoryModel.color.swiftUIColor.opacity(0.18)), lineWidth: 0.9)
            }
        }
        .allowsHitTesting(false)
    }

    private func stageTrajectory(in size: CGSize, center: CGPoint, orbit: CGSize) -> some View {
        ZStack {
            Canvas { context, canvasSize in
                let canvasCenter = mapCenter(in: canvasSize)
                var path = Path()
                for (index, stage) in universeStageOrder.enumerated() {
                    let point = stageMarkerProjection(stage: stage, in: canvasSize, center: canvasCenter, orbit: orbit).point
                    if index == 0 {
                        path.move(to: point)
                    } else {
                        path.addLine(to: point)
                    }
                }
                context.stroke(
                    path,
                    with: .linearGradient(
                        Gradient(colors: [
                            selectedCategoryModel.color.swiftUIColor.opacity(0.14),
                            selectedCategoryModel.glow.swiftUIColor.opacity(0.42),
                            selectedCategoryModel.color.swiftUIColor.opacity(0.14),
                        ]),
                        startPoint: CGPoint(x: canvasCenter.x - canvasSize.width * 0.38, y: canvasCenter.y),
                        endPoint: CGPoint(x: canvasCenter.x + canvasSize.width * 0.38, y: canvasCenter.y)
                    ),
                    style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round, dash: [1, 8])
                )
            }

            ForEach(universeStageOrder, id: \.self) { stage in
                let projection = stageMarkerProjection(stage: stage, in: size, center: center, orbit: orbit)
                StageMarker(
                    title: stageShortLabel(stage),
                    color: selectedCategoryModel.color.swiftUIColor,
                    isActive: selectedToolStage == stage
                )
                .scaleEffect(projection.scale)
                .opacity(projection.opacity)
                .position(projection.point)
                .zIndex(projection.zIndex)
            }
        }
        .allowsHitTesting(false)
    }

    private func overviewNodes(in size: CGSize, center: CGPoint, orbit: CGSize) -> some View {
        ZStack {
            ForEach(visibleCategories) { category in
                let categoryBasePoint = categoryBasePosition(category, in: size, center: center)
                let categoryProjection = sphereProjection(for: categoryBasePoint, in: size, center: center, orbit: orbit)
                ForEach(tools.filter { $0.category == category.id }.prefix(3)) { tool in
                    let projection = overviewToolProjection(tool: tool, category: category, categoryBasePoint: categoryBasePoint, in: size, center: center, orbit: orbit)
                    MapNode(
                        title: tool.name,
                        subtitle: stageShortLabel(tool.stage),
                        color: category.color.swiftUIColor,
                        diameter: tool.id == selectedToolId ? 42 : (visualizationStyle == .force3D ? 28 : 22),
                        showsLabel: tool.id == selectedToolId || visualizationStyle == .atlasOverlay,
                        isSelected: tool.id == selectedToolId,
                        opacity: projection.opacity,
                        style: visualizationStyle,
                        depth: projection.scale,
                        action: { onToolSelect(tool.id) }
                    )
                    .position(projection.point)
                    .zIndex(projection.zIndex)
                }

                MapNode(
                    title: category.shortName,
                    subtitle: "\(tools.filter { $0.category == category.id }.count) tools",
                    color: category.color.swiftUIColor,
                    diameter: category.id == selectedCategory ? 68 : 52,
                    showsLabel: true,
                    isSelected: category.id == selectedCategory,
                    opacity: categoryProjection.opacity,
                    style: visualizationStyle,
                    depth: categoryProjection.scale,
                    action: { onCategorySelect(category.id) }
                )
                .position(categoryProjection.point)
                .zIndex(categoryProjection.zIndex)
            }

            let coreProjection = sphereProjection(for: center, in: size, center: center, orbit: orbit)
            MapNode(
                title: "Founder OS",
                subtitle: "Core",
                color: UniverseSeed.category(.core).color.swiftUIColor,
                diameter: 92 * CGFloat(visualizationStyle.categoryScale),
                showsLabel: true,
                isSelected: selectedToolId == "founder-os",
                opacity: max(0.88, coreProjection.opacity),
                style: visualizationStyle,
                depth: max(1.02, coreProjection.scale),
                action: { onToolSelect("founder-os") }
            )
            .position(center)
            .zIndex(2)
        }
        .brandAnimation(BrandMotion.flow, value: selectedCategory)
        .brandAnimation(BrandMotion.flow, value: selectedToolId)
    }

    private func pocketNodes(in size: CGSize, center: CGPoint, orbit: CGSize) -> some View {
        ZStack {
            ForEach(visibleCategories.filter { $0.id != selectedCategory }) { category in
                let projection = categoryProjection(category, in: size, center: center, orbit: orbit)
                MapNode(
                    title: category.shortName,
                    subtitle: "",
                    color: category.color.swiftUIColor,
                    diameter: 28,
                    showsLabel: visualizationStyle == .atlasOverlay,
                    isSelected: false,
                    opacity: 0.22,
                    style: visualizationStyle,
                    depth: projection.scale,
                    action: { onCategorySelect(category.id) }
                )
                .opacity(projection.opacity)
                .position(projection.point)
                .zIndex(projection.zIndex)
            }

            let selectedProjection = sphereProjection(for: center, in: size, center: center, orbit: orbit)
            let isToolFocused = selectedCategoryTools.contains { $0.id == selectedToolId }
            MapNode(
                title: selectedCategoryModel.shortName,
                subtitle: selectedCategoryModel.name,
                color: selectedCategoryModel.color.swiftUIColor,
                diameter: 88 * CGFloat(visualizationStyle.categoryScale),
                showsLabel: !isToolFocused,
                isSelected: true,
                opacity: max(0.9, selectedProjection.opacity),
                style: visualizationStyle,
                depth: max(1.02, selectedProjection.scale),
                action: { onCategorySelect(.core) }
            )
            .position(center)
            .zIndex(2)

            ForEach(Array(selectedCategoryTools.enumerated()), id: \.element.id) { index, tool in
                let projection = pocketToolProjection(tool: tool, index: index, count: selectedCategoryTools.count, in: size, center: center, orbit: orbit)
                MapNode(
                    title: tool.name,
                    subtitle: stageShortLabel(tool.stage),
                    color: selectedCategoryModel.color.swiftUIColor,
                    diameter: tool.id == selectedToolId ? 72 : 52,
                    showsLabel: true,
                    isSelected: tool.id == selectedToolId,
                    opacity: projection.opacity,
                    style: visualizationStyle,
                    depth: projection.scale,
                    action: { onToolSelect(tool.id) }
                )
                .position(projection.point)
                .zIndex(projection.zIndex)
            }

            let coreBasePoint = CGPoint(x: center.x, y: max(72, center.y - min(size.height * 0.28, 210)))
            let coreProjection = sphereProjection(for: coreBasePoint, in: size, center: center, orbit: orbit)
            MapNode(
                title: "Core",
                subtitle: "",
                color: UniverseSeed.category(.core).color.swiftUIColor,
                diameter: 40,
                showsLabel: false,
                isSelected: false,
                opacity: 0.72,
                style: visualizationStyle,
                depth: coreProjection.scale,
                action: { onCategorySelect(.core) }
            )
            .opacity(coreProjection.opacity)
            .position(coreProjection.point)
            .zIndex(coreProjection.zIndex)
        }
        .brandAnimation(BrandMotion.flow, value: selectedCategory)
        .brandAnimation(BrandMotion.flow, value: selectedToolId)
    }

    private func ambientReadout(in size: CGSize) -> some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Text(visualizationStyle.shortLabel)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(selectedCategoryModel.color.swiftUIColor.opacity(0.62))
                    .frame(width: 26, height: 26)
                    .background(.white.opacity(0.035), in: Circle())
                    .overlay {
                        Circle().stroke(selectedCategoryModel.color.swiftUIColor.opacity(0.16), lineWidth: 1)
                    }
                    .padding(.trailing, 18)
                    .padding(.bottom, max(236, size.height * 0.27))
            }
        }
        .allowsHitTesting(false)
    }

    private var selectedToolStage: WorkflowStageId? {
        tools.first { $0.id == selectedToolId }?.stage
    }

    private func mapCenter(in size: CGSize) -> CGPoint {
        let y = visualizationStyle == .force3D ? size.height * 0.37 : size.height * 0.39
        return CGPoint(x: size.width * 0.5, y: y)
    }

    private func surfaceOrbitGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .local)
            .updating($activeOrbitDrag) { value, state, _ in
                state = value.translation
            }
            .onChanged { value in
                let distance = sqrt(value.translation.width * value.translation.width + value.translation.height * value.translation.height)
                guard distance > 8, !isOrbitingSurface else { return }
                isOrbitingSurface = true
                BrandHaptics.fire(.light)
            }
            .onEnded { value in
                let dragDistance = hypot(value.translation.width, value.translation.height)
                let projected = projectedOrbit(from: value)
                let nearest = nearestAnchor(in: size, orbit: projected, excludingCurrent: dragDistance > 28)
                let shouldDock = dragDistance > 28 && nearest != nil
                let dockedOrbit = shouldDock && nearest != nil ? focusedOrbit(for: nearest!.basePoint, in: size) : projected

                withAnimation(BrandMotion.resolved(.spring(response: 0.52, dampingFraction: 0.82), reduceMotion: reduceMotion)) {
                    settledOrbit = dockedOrbit
                    isOrbitingSurface = false
                }

                if shouldDock, let nearest {
                    BrandHaptics.fire(.medium)
                    select(nearest.target)
                }
            }
    }

    private func surfaceZoomGesture() -> some Gesture {
        MagnifyGesture()
            .onChanged { value in
                if zoomGestureStart == nil {
                    zoomGestureStart = zoomScale
                    BrandHaptics.fire(.light)
                }
                zoomScale = clampedZoom((zoomGestureStart ?? 1) * value.magnification)
            }
            .onEnded { value in
                let nextZoom = clampedZoom((zoomGestureStart ?? zoomScale) * value.magnification)
                withAnimation(BrandMotion.resolved(.spring(response: 0.36, dampingFraction: 0.86), reduceMotion: reduceMotion)) {
                    zoomScale = nextZoom
                    zoomGestureStart = nil
                }
                BrandHaptics.fire(.light)
            }
    }

    private func currentOrbit(in size: CGSize) -> CGSize {
        let active = orbitDrag(from: activeOrbitDrag)
        return clampedOrbit(
            CGSize(
                width: settledOrbit.width + active.width,
                height: settledOrbit.height + active.height
            )
        )
    }

    private func projectedOrbit(from value: DragGesture.Value) -> CGSize {
        let drag = orbitDrag(from: value.translation)
        let predictedDrag = orbitDrag(from: value.predictedEndTranslation)
        let velocityCarry = CGSize(
            width: (predictedDrag.width - drag.width) * 0.12,
            height: (predictedDrag.height - drag.height) * 0.12
        )
        return clampedOrbit(
            CGSize(
                width: settledOrbit.width + drag.width + velocityCarry.width,
                height: settledOrbit.height + drag.height + velocityCarry.height
            )
        )
    }

    private func orbitDrag(from translation: CGSize) -> CGSize {
        CGSize(width: translation.width * 0.46, height: -translation.height * 0.36)
    }

    private func clampedOrbit(_ orbit: CGSize) -> CGSize {
        return CGSize(
            width: normalizedYaw(orbit.width),
            height: min(max(orbit.height, -62), 62)
        )
    }

    private func normalizedYaw(_ yaw: CGFloat) -> CGFloat {
        var result = yaw.truncatingRemainder(dividingBy: 360)
        if result > 180 {
            result -= 360
        } else if result < -180 {
            result += 360
        }
        return result
    }

    private func focusedOrbit(for basePoint: CGPoint, in size: CGSize) -> CGSize {
        let center = mapCenter(in: size)
        let normalized = normalizedSpherePoint(for: basePoint, in: size, center: center)
        guard abs(normalized.x) > 0.001 || abs(normalized.y) > 0.001 else {
            return .zero
        }

        let yaw = atan2(-normalized.x, max(normalized.z, 0.001)) * 180 / .pi
        let zAfterYaw = -normalized.x * sin(yaw * .pi / 180) + normalized.z * cos(yaw * .pi / 180)
        let pitch = atan2(normalized.y, max(zAfterYaw, 0.001)) * 180 / .pi
        return clampedOrbit(CGSize(width: yaw, height: pitch))
    }

    private func sphereProjection(for basePoint: CGPoint, in size: CGSize, center: CGPoint, orbit: CGSize) -> SphereProjection {
        let normalized = normalizedSpherePoint(for: basePoint, in: size, center: center)
        let yaw = orbit.width * .pi / 180
        let pitch = orbit.height * .pi / 180

        let rotatedX = normalized.x * cos(yaw) + normalized.z * sin(yaw)
        let rotatedZ = -normalized.x * sin(yaw) + normalized.z * cos(yaw)
        let rotatedY = normalized.y * cos(pitch) - rotatedZ * sin(pitch)
        let finalZ = normalized.y * sin(pitch) + rotatedZ * cos(pitch)
        let depth = min(max((finalZ + 1) / 2, 0), 1)
        let perspective = 0.78 + depth * 0.28

        let point = CGPoint(
            x: center.x + rotatedX * sphereRadiusX(in: size) * perspective,
            y: center.y + rotatedY * sphereRadiusY(in: size) * perspective
        )

        return SphereProjection(
            point: point,
            depth: depth,
            scale: 0.55 + depth * 0.62,
            opacity: Double(0.2 + depth * 0.8)
        )
    }

    private func normalizedSpherePoint(for point: CGPoint, in size: CGSize, center: CGPoint) -> SpherePoint {
        let radiusX = max(sphereRadiusX(in: size), 1)
        let radiusY = max(sphereRadiusY(in: size), 1)
        var x = (point.x - center.x) / radiusX
        var y = (point.y - center.y) / radiusY
        let length = sqrt(x * x + y * y)
        if length > 0.985 {
            x = x / length * 0.985
            y = y / length * 0.985
        }
        let z = sqrt(max(0.03, 1 - x * x - y * y))
        return SpherePoint(x: x, y: y, z: z)
    }

    private func sphereRadiusX(in size: CGSize) -> CGFloat {
        min(size.width * 0.45, 192) * visualizationStyle.mapSpread
    }

    private func sphereRadiusY(in size: CGSize) -> CGFloat {
        min(size.height * (selectedCategory == .core ? 0.31 : 0.34), 252) * visualizationStyle.mapSpread
    }

    private func clampedZoom(_ value: CGFloat) -> CGFloat {
        min(max(value, 0.72), 1.82)
    }

    private func flyToSelectedAnchor(in size: CGSize, resetZoom: Bool) {
        let target = selectedAnchorPoint(in: size) ?? mapCenter(in: size)
        withAnimation(BrandMotion.resolved(BrandMotion.flow, reduceMotion: reduceMotion)) {
            settledOrbit = focusedOrbit(for: target, in: size)
            if resetZoom {
                zoomScale = visualizationStyle.defaultCameraZoom
            }
            isOrbitingSurface = false
        }
    }

    private func selectedAnchorPoint(in size: CGSize) -> CGPoint? {
        let center = mapCenter(in: size)
        if selectedCategory == .core {
            if selectedToolId == "founder-os" {
                return center
            }
            guard let tool = tools.first(where: { $0.id == selectedToolId }) else { return center }
            let category = UniverseSeed.category(tool.category)
            let categoryPoint = categoryBasePosition(category, in: size, center: center)
            return overviewToolBasePosition(tool: tool, category: category, categoryBasePoint: categoryPoint, in: size, center: center)
        }

        guard let index = selectedCategoryTools.firstIndex(where: { $0.id == selectedToolId }) else {
            return center
        }
        return pocketToolBasePosition(
            tool: selectedCategoryTools[index],
            index: index,
            count: selectedCategoryTools.count,
            in: size,
            center: center
        )
    }

    private func nearestAnchor(in size: CGSize, orbit: CGSize, excludingCurrent: Bool = false) -> FlightAnchor? {
        let center = mapCenter(in: size)
        return flightAnchors(in: size, center: center)
            .filter { anchor in
                !excludingCurrent || !isCurrent(anchor.target)
            }
            .map { anchor in
                let projection = sphereProjection(for: anchor.basePoint, in: size, center: center, orbit: orbit)
                let distance = hypot(projection.point.x - center.x, projection.point.y - center.y)
                return anchor.withProjection(projection, distance: distance)
            }
            .min { lhs, rhs in
                lhs.screenDistance + lhs.depthPenalty < rhs.screenDistance + rhs.depthPenalty
            }
    }

    private func flightAnchors(in size: CGSize, center: CGPoint) -> [FlightAnchor] {
        var anchors: [FlightAnchor] = [
            FlightAnchor(basePoint: center, target: .tool("founder-os"))
        ]

        if selectedCategory == .core {
            for category in visibleCategories {
                let categoryPoint = categoryBasePosition(category, in: size, center: center)
                anchors.append(FlightAnchor(basePoint: categoryPoint, target: .category(category.id)))
                for tool in tools.filter({ $0.category == category.id }).prefix(3) {
                    anchors.append(
                        FlightAnchor(
                            basePoint: overviewToolBasePosition(tool: tool, category: category, categoryBasePoint: categoryPoint, in: size, center: center),
                            target: .tool(tool.id)
                        )
                    )
                }
            }
        } else {
            anchors.append(FlightAnchor(basePoint: center, target: .category(selectedCategory)))
            for category in visibleCategories {
                anchors.append(FlightAnchor(basePoint: categoryBasePosition(category, in: size, center: center), target: .category(category.id)))
            }
            for (index, tool) in selectedCategoryTools.enumerated() {
                anchors.append(
                    FlightAnchor(
                        basePoint: pocketToolBasePosition(tool: tool, index: index, count: selectedCategoryTools.count, in: size, center: center),
                        target: .tool(tool.id)
                    )
                )
            }
        }

        return anchors
    }

    private func select(_ target: FlightTarget) {
        switch target {
        case .category(let id):
            onCategorySelect(id)
        case .tool(let id):
            onToolSelect(id)
        }
    }

    private func isCurrent(_ target: FlightTarget) -> Bool {
        switch target {
        case .category(let id):
            return id == selectedCategory
        case .tool(let id):
            return id == selectedToolId
        }
    }

    private func categoryProjection(_ category: ToolCategory, in size: CGSize, center: CGPoint, orbit: CGSize) -> SphereProjection {
        sphereProjection(for: categoryBasePosition(category, in: size, center: center), in: size, center: center, orbit: orbit)
    }

    private func categoryBasePosition(_ category: ToolCategory, in size: CGSize, center: CGPoint) -> CGPoint {
        let phase = visualizationStyle == .force3D && !reduceMotion ? CGFloat(orbitPhase * 0.018) : 0
        let radians = (CGFloat(category.angle) + phase) * .pi / 180
        let spread = visualizationStyle.mapSpread
        let radiusX = min(size.width * (visualizationStyle == .force3D ? 0.34 : 0.35), visualizationStyle == .force3D ? 158 : 166) * CGFloat(visualizationStyle.categoryScale) * spread
        let radiusY = min(size.height * (selectedCategory == .core ? 0.215 : 0.255), 222) * CGFloat(visualizationStyle.categoryScale) * spread
        let depthShift = visualizationStyle == .force3D ? sin(radians) * 26 : 0
        return CGPoint(
            x: center.x + cos(radians) * radiusX,
            y: center.y + sin(radians) * radiusY + depthShift
        )
    }

    private func overviewToolProjection(
        tool: Tool,
        category: ToolCategory,
        categoryBasePoint: CGPoint,
        in size: CGSize,
        center: CGPoint,
        orbit: CGSize
    ) -> SphereProjection {
        sphereProjection(
            for: overviewToolBasePosition(tool: tool, category: category, categoryBasePoint: categoryBasePoint, in: size, center: center),
            in: size,
            center: center,
            orbit: orbit
        )
    }

    private func overviewToolBasePosition(tool: Tool, category: ToolCategory, categoryBasePoint: CGPoint, in size: CGSize, center: CGPoint) -> CGPoint {
        let phase = visualizationStyle == .force3D && !reduceMotion ? CGFloat(orbitPhase * 0.045) : 0
        let radians = (CGFloat(tool.angle + 24) + phase) * .pi / 180
        let orbit = CGFloat(tool.orbit.rawValue)
        let radius = ((visualizationStyle == .force3D ? 28 : 20) + orbit * 12 * CGFloat(visualizationStyle.nodeScale)) * visualizationStyle.mapSpread
        let rawPoint = CGPoint(
            x: categoryBasePoint.x + cos(radians) * radius,
            y: categoryBasePoint.y + sin(radians) * radius * 0.76
        )
        guard visualizationStyle == .force3D else { return rawPoint }
        let stagePoint = stageMarkerBasePosition(stage: tool.stage, in: size, center: center)
        return CGPoint(
            x: rawPoint.x * 0.72 + stagePoint.x * 0.28,
            y: rawPoint.y * 0.70 + stagePoint.y * 0.30
        )
    }

    private func pocketToolProjection(tool: Tool, index: Int, count: Int, in size: CGSize, center: CGPoint, orbit: CGSize) -> SphereProjection {
        sphereProjection(
            for: pocketToolBasePosition(tool: tool, index: index, count: count, in: size, center: center),
            in: size,
            center: center,
            orbit: orbit
        )
    }

    private func pocketToolBasePosition(tool: Tool, index: Int, count: Int, in size: CGSize, center: CGPoint) -> CGPoint {
        if visualizationStyle == .force3D {
            let base = stageMarkerBasePosition(stage: tool.stage, in: size, center: center)
            let phase = reduceMotion ? 0 : CGFloat(orbitPhase * 0.04)
            let radians = (CGFloat(tool.angle) + CGFloat(index) * 19 + phase) * .pi / 180
            let orbit = CGFloat(tool.orbit.rawValue)
            let radius = (20 + orbit * 13) * visualizationStyle.mapSpread
            let stackOffset = CGFloat((index % 3) - 1) * 12
            return CGPoint(
                x: base.x + cos(radians) * radius + stackOffset,
                y: base.y + sin(radians) * radius * 0.64 - orbit * 8
            )
        }

        let step = count > 0 ? 360 / CGFloat(count) : 360
        let baseAngle = CGFloat(tool.angle) + CGFloat(index) * step * 0.22 + orbitPhase * (reduceMotion ? 0 : 0.015)
        let radians = baseAngle * .pi / 180
        let orbit = CGFloat(tool.orbit.rawValue)
        let radiusX = (min(size.width * 0.34, 168) + orbit * 10) * visualizationStyle.mapSpread
        let radiusY = (min(size.height * 0.17, 142) + orbit * 7) * visualizationStyle.mapSpread
        return CGPoint(
            x: center.x + cos(radians) * radiusX,
            y: center.y + sin(radians) * radiusY
        )
    }

    private func stageMarkerProjection(stage: WorkflowStageId, in size: CGSize, center: CGPoint, orbit: CGSize) -> SphereProjection {
        sphereProjection(for: stageMarkerBasePosition(stage: stage, in: size, center: center), in: size, center: center, orbit: orbit)
    }

    private func stageMarkerBasePosition(stage: WorkflowStageId, in size: CGSize, center: CGPoint) -> CGPoint {
        let index = CGFloat(stageIndex(stage))
        let count = CGFloat(max(universeStageOrder.count - 1, 1))
        let width = min(size.width * 0.72, 296)
        let baseY = center.y + min(size.height * 0.225, 178)
        let wave = reduceMotion ? 0 : sin((index * 0.86) + CGFloat(orbitPhase * 0.018)) * 16
        return CGPoint(
            x: center.x - width / 2 + width * (index / count),
            y: baseY + wave
        )
    }

    private func stageIndex(_ stage: WorkflowStageId) -> Int {
        universeStageOrder.firstIndex(of: stage) ?? 0
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

    private func depth(for stage: WorkflowStageId) -> CGFloat {
        guard visualizationStyle == .force3D else { return 1 }
        let normalized = CGFloat(stageIndex(stage)) / CGFloat(max(universeStageOrder.count - 1, 1))
        return 0.92 + normalized * 0.22
    }

    private func depth(for category: ToolCategoryId) -> CGFloat {
        guard visualizationStyle == .force3D, let index = visibleCategories.firstIndex(where: { $0.id == category }) else {
            return 1
        }
        return 0.92 + CGFloat(index % 4) * 0.055
    }

    private func ringWidth(for ring: Int, in size: CGSize) -> CGFloat {
        let base = min(size.width * 0.58, size.height * 0.39)
        return (base + CGFloat(ring) * min(size.width * 0.14, 72)) * visualizationStyle.mapSpread
    }

    private func ringAspect(for ring: Int) -> CGFloat {
        switch visualizationStyle {
        case .atlasOverlay: return 0.78 - CGFloat(ring) * 0.025
        case .kineticPockets: return 0.68 - CGFloat(ring) * 0.015
        case .force3D: return 0.58 - CGFloat(ring) * 0.01
        case .orbitalGlass: return 0.72 - CGFloat(ring) * 0.02
        }
    }

    private func starPoint(index: Int, size: CGSize) -> CGPoint {
        let xSeed = CGFloat((index * 73 + 19) % 997) / 997
        let ySeed = CGFloat((index * 131 + 47) % 991) / 991
        return CGPoint(x: xSeed * size.width, y: ySeed * size.height)
    }
}

private enum FlightTarget: Equatable {
    case category(ToolCategoryId)
    case tool(String)
}

private struct SpherePoint {
    let x: CGFloat
    let y: CGFloat
    let z: CGFloat
}

private struct SphereProjection {
    let point: CGPoint
    let depth: CGFloat
    let scale: CGFloat
    let opacity: Double

    var zIndex: Double {
        Double(depth)
    }
}

private struct FlightAnchor {
    let basePoint: CGPoint
    let target: FlightTarget
    var screenDistance: CGFloat = .greatestFiniteMagnitude
    var depth: CGFloat = 1

    var depthPenalty: CGFloat {
        (1 - depth) * 84
    }

    func withProjection(_ projection: SphereProjection, distance: CGFloat) -> FlightAnchor {
        FlightAnchor(basePoint: basePoint, target: target, screenDistance: distance, depth: projection.depth)
    }
}

private extension CGSize {
    var pitchRatio: CGFloat {
        min(max(height / 62, -1), 1)
    }
}

private extension VisualizationStyle {
    var mapSpread: CGFloat {
        switch self {
        case .atlasOverlay: return 0.86
        case .kineticPockets: return 1.16
        case .force3D: return 1.28
        case .orbitalGlass: return 1.0
        }
    }

    var defaultCameraZoom: CGFloat {
        switch self {
        case .atlasOverlay: return 0.92
        case .kineticPockets: return 1.08
        case .force3D: return 1.18
        case .orbitalGlass: return 1.0
        }
    }
}

private struct MapNode: View {
    let title: String
    let subtitle: String
    let color: Color
    let diameter: CGFloat
    let showsLabel: Bool
    let isSelected: Bool
    var opacity: Double = 1
    var style: VisualizationStyle = .orbitalGlass
    var depth: CGFloat = 1
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            let renderedDiameter = diameter * depth
            let nodeFrame = max(renderedDiameter * 2.36, 58)
            VStack(spacing: style == .force3D ? 8 : 6) {
                ZStack {
                    Ellipse()
                        .fill(.black.opacity(style == .force3D ? 0.42 : 0.32))
                        .frame(width: renderedDiameter * 1.42, height: renderedDiameter * 0.28)
                        .blur(radius: renderedDiameter * 0.16)
                        .offset(y: renderedDiameter * 0.62)

                    Circle()
                        .fill(color.opacity(isSelected ? 0.42 : 0.21))
                        .frame(width: renderedDiameter * 2.08, height: renderedDiameter * 2.08)
                        .blur(radius: renderedDiameter * 0.42)

                    Circle()
                        .stroke(color.opacity(isSelected ? 0.26 : 0.12), lineWidth: max(1, renderedDiameter * 0.035))
                        .frame(width: renderedDiameter * 1.78, height: renderedDiameter * 1.78)
                        .blur(radius: renderedDiameter * 0.045)

                    if showsPlanetRing(for: renderedDiameter) {
                        PlanetRing(color: color, diameter: renderedDiameter, isSelected: isSelected, style: style, layer: .back)
                    }

                    PlanetSphere(color: color, diameter: renderedDiameter, isSelected: isSelected, style: style)

                    if showsPlanetRing(for: renderedDiameter) {
                        PlanetRing(color: color, diameter: renderedDiameter, isSelected: isSelected, style: style, layer: .front)
                    }

                    if isSelected {
                        Circle()
                            .stroke(
                                AngularGradient(
                                    colors: [
                                        .white.opacity(0.36),
                                        color.opacity(0.78),
                                        .white.opacity(0.18),
                                        color.opacity(0.48),
                                        .white.opacity(0.36),
                                    ],
                                    center: .center
                                ),
                                lineWidth: 1.25
                            )
                            .frame(width: renderedDiameter + 14, height: renderedDiameter + 14)

                        Circle()
                            .stroke(color.opacity(0.2), lineWidth: 1)
                            .frame(width: renderedDiameter + 24, height: renderedDiameter + 24)
                            .blur(radius: 0.6)
                    }
                }
                .frame(width: nodeFrame, height: nodeFrame * 0.94)

                if showsLabel {
                    VStack(spacing: 3) {
                        Text(title)
                            .font(.system(size: isSelected ? 13 : 12, weight: .semibold))
                            .foregroundStyle(BrandColor.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                        if !subtitle.isEmpty {
                            Text(subtitle)
                                .font(.system(size: isSelected ? 10 : 9, weight: .medium))
                                .foregroundStyle(BrandColor.textSecondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.78)
                        }
                    }
                    .frame(width: isSelected ? 124 : 108)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(.black.opacity(style == .force3D ? 0.66 : 0.58), in: Capsule())
                    .overlay {
                        Capsule().stroke(color.opacity(isSelected ? 0.38 : 0.18), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.34), radius: 8, x: 0, y: 5)
                }
            }
            .opacity(opacity)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(PlanetButtonStyle(isSelected: isSelected, style: style))
        .accessibilityLabel(title)
    }

    private func showsPlanetRing(for renderedDiameter: CGFloat) -> Bool {
        isSelected || renderedDiameter >= 42 || style == .force3D || style == .orbitalGlass
    }
}

private struct PlanetSphere: View {
    let color: Color
    let diameter: CGFloat
    let isSelected: Bool
    let style: VisualizationStyle

    var body: some View {
        Circle()
            .fill(.black.opacity(style == .force3D ? 0.66 : 0.54))
            .frame(width: diameter, height: diameter)
            .overlay {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                .white.opacity(style == .force3D ? 0.86 : 0.56),
                                color.opacity(isSelected ? 1 : 0.86),
                                color.opacity(style == .force3D ? 0.5 : 0.28),
                                .black.opacity(style == .force3D ? 0.34 : 0.2),
                            ],
                            center: .topLeading,
                            startRadius: 1,
                            endRadius: diameter * 0.96
                        )
                    )
            }
            .overlay {
                PlanetSurfaceLines(color: color, diameter: diameter, isSelected: isSelected)
            }
            .overlay(alignment: .topLeading) {
                Circle()
                    .fill(.white.opacity(isSelected ? 0.48 : 0.28))
                    .frame(width: diameter * 0.24, height: diameter * 0.24)
                    .blur(radius: diameter * 0.035)
                    .offset(x: diameter * 0.2, y: diameter * 0.18)
            }
            .overlay(alignment: .bottomTrailing) {
                Circle()
                    .fill(.black.opacity(style == .force3D ? 0.26 : 0.18))
                    .frame(width: diameter * 0.82, height: diameter * 0.82)
                    .blur(radius: diameter * 0.16)
                    .offset(x: diameter * 0.18, y: diameter * 0.18)
            }
            .overlay {
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(isSelected ? 0.42 : 0.24),
                                color.opacity(isSelected ? 0.92 : 0.5),
                                .black.opacity(0.22),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isSelected ? 1.9 : 1.05
                    )
            }
            .shadow(color: color.opacity(isSelected ? 0.68 : 0.34), radius: isSelected ? 24 : 13, x: 0, y: style == .force3D ? 10 : 7)
            .shadow(color: .black.opacity(0.38), radius: 15, x: 0, y: 12)
    }
}

private struct PlanetSurfaceLines: View {
    let color: Color
    let diameter: CGFloat
    let isSelected: Bool

    var body: some View {
        ZStack {
            Ellipse()
                .stroke(.white.opacity(isSelected ? 0.2 : 0.13), lineWidth: max(0.55, diameter * 0.012))
                .frame(width: diameter * 0.82, height: diameter * 0.34)
                .rotationEffect(.degrees(-9))
                .offset(y: -diameter * 0.08)

            Ellipse()
                .stroke(color.opacity(isSelected ? 0.46 : 0.28), lineWidth: max(0.55, diameter * 0.013))
                .frame(width: diameter * 0.92, height: diameter * 0.44)
                .rotationEffect(.degrees(12))
                .offset(y: diameter * 0.11)

            Ellipse()
                .stroke(.white.opacity(isSelected ? 0.16 : 0.1), lineWidth: max(0.45, diameter * 0.01))
                .frame(width: diameter * 0.36, height: diameter * 0.9)
                .rotationEffect(.degrees(9))
        }
        .frame(width: diameter, height: diameter)
        .clipShape(Circle())
        .blendMode(.screen)
    }
}

private struct PlanetRing: View {
    enum Layer {
        case back
        case front
    }

    let color: Color
    let diameter: CGFloat
    let isSelected: Bool
    let style: VisualizationStyle
    let layer: Layer

    var body: some View {
        Ellipse()
            .trim(from: layer == .back ? 0.02 : 0.52, to: layer == .back ? 0.51 : 0.98)
            .stroke(
                LinearGradient(
                    colors: [
                        .white.opacity(layer == .front ? 0.34 : 0.12),
                        color.opacity(layer == .front ? frontOpacity : backOpacity),
                        .white.opacity(layer == .front ? 0.18 : 0.08),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
            )
            .frame(width: diameter * ringWidthMultiplier, height: diameter * ringHeightMultiplier)
            .rotationEffect(.degrees(style == .force3D ? -19 : -14))
            .shadow(color: color.opacity(layer == .front ? 0.32 : 0.18), radius: isSelected ? 8 : 4, x: 0, y: 0)
            .opacity(layer == .front ? 1 : 0.82)
    }

    private var frontOpacity: Double {
        isSelected ? 0.78 : 0.48
    }

    private var backOpacity: Double {
        isSelected ? 0.44 : 0.24
    }

    private var lineWidth: CGFloat {
        max(0.85, diameter * (isSelected ? 0.036 : 0.024))
    }

    private var ringWidthMultiplier: CGFloat {
        style == .force3D ? 1.76 : 1.62
    }

    private var ringHeightMultiplier: CGFloat {
        style == .force3D ? 0.5 : 0.44
    }
}

private struct PlanetButtonStyle: ButtonStyle {
    let isSelected: Bool
    let style: VisualizationStyle

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(scale(isPressed: configuration.isPressed))
            .brightness(configuration.isPressed ? 0.055 : 0)
            .shadow(
                color: .white.opacity(configuration.isPressed ? 0.14 : 0),
                radius: configuration.isPressed ? 12 : 0,
                x: 0,
                y: 0
            )
            .brandAnimation(BrandMotion.nudge, value: configuration.isPressed)
    }

    private func scale(isPressed: Bool) -> CGFloat {
        guard isPressed, !reduceMotion else { return 1 }
        if style == .force3D {
            return isSelected ? 0.975 : 0.95
        }
        return isSelected ? 0.985 : 0.955
    }
}

private struct StageMarker: View {
    let title: String
    let color: Color
    let isActive: Bool

    var body: some View {
        VStack(spacing: 5) {
            Circle()
                .fill(isActive ? color : .white.opacity(0.18))
                .frame(width: isActive ? 10 : 6, height: isActive ? 10 : 6)
                .shadow(color: color.opacity(isActive ? 0.7 : 0.2), radius: isActive ? 9 : 4)

            Text(title)
                .font(.system(size: isActive ? 11 : 10, weight: isActive ? .semibold : .medium))
                .foregroundStyle(isActive ? .white : .white.opacity(0.52))
                .lineLimit(1)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(.black.opacity(isActive ? 0.52 : 0.28), in: Capsule())
                .overlay {
                    Capsule().stroke(color.opacity(isActive ? 0.34 : 0.12), lineWidth: 1)
                }
        }
    }
}

#Preview {
    UniverseMapSurface(
        selectedCategory: .coding,
        selectedToolId: "codex",
        tools: UniverseSeed.tools,
        visualizationStyle: .orbitalGlass,
        onCategorySelect: { _ in },
        onToolSelect: { _ in }
    )
    .preferredColorScheme(.dark)
}
