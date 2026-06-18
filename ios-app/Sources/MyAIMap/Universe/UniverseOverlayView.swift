import SwiftUI
import simd

struct UniverseOverlayView: View {
    @Environment(UniverseViewModel.self) private var model

    let planets: [PlanetData]
    let mode: UniverseMode
    let cameraRig: CameraRigController
    let selectedPlanet: PlanetData
    let selectedTool: Tool
    let onCategorySelect: (ToolCategoryId) -> Void
    let onToolSelect: (String) -> Void
    let onChatActivityChange: (Bool) -> Void
    let onDetails: () -> Void
    let onAccount: () -> Void
    let onAddTool: () -> Void

    @State private var isRailActive = false

    private var isFocusedOnTool: Bool {
        mode.selectedToolID != nil && selectedTool.category == selectedPlanet.id && selectedPlanet.id != .core
    }

    var body: some View {
        ZStack {
            if mode.showsPlanetLabels && !cameraRig.isTransitioning {
                labelLayer
                    .allowsHitTesting(false)
            }

            if mode.showsToolAnchor && !cameraRig.isTransitioning {
                toolAnchorLayer
                    .allowsHitTesting(false)
            }

            if mode.showsToolLabels && !cameraRig.isTransitioning {
                toolLabelLayer
                    .allowsHitTesting(false)
            }

            if isRailActive {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .overlay(Color.black.opacity(0.28))
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }

            VStack(spacing: 0) {
                if !mode.isDetailOpen && !mode.isChatOpen {
                    topChrome
                        .padding(.horizontal, 16)
                        .padding(.top, 14)
                }

                Spacer()

                bottomControls
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
            }

            if !mode.isDetailOpen && !mode.isChatOpen && !cameraRig.isTransitioning {
                rightUniverseRail
            }
        }
    }

    private var labelLayer: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                if mode == .overview {
                    ForEach(overviewLabelPlacements(in: size)) { placement in
                        placedLabelView(placement)
                    }
                } else {
                    ForEach(planets) { planet in
                        labelView(for: planet, in: size)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func labelView(for planet: PlanetData, in size: CGSize) -> some View {
        let projection = cameraRig.projection(for: planet.position3D, in: size)
        if shouldShowLabel(for: planet, projection: projection) {
            let position = labelPosition(for: planet, projection: projection, in: size)
            placedLabelView(PlanetLabelPlacement(planet: planet, projection: projection, position: position))
        }
    }

    private func placedLabelView(_ placement: PlanetLabelPlacement) -> some View {
        let planet = placement.planet
        return ZStack {
            LabelLeaderLine(
                from: placement.projection.point,
                to: placement.position,
                color: planet.swiftUIColor,
                isSelected: planet.id == selectedPlanet.id
            )
            .opacity(placement.projection.opacity * (planet.id == selectedPlanet.id ? 0.72 : 0.36))

            PlanetFloatingLabel(
                title: planet.title,
                subtitle: planet.id == .core ? "Core" : "\(planet.toolCount) tools",
                color: planet.swiftUIColor,
                isSelected: planet.id == selectedPlanet.id
            )
            .scaleEffect(placement.projection.scale)
            .opacity(planet.id == selectedPlanet.id ? max(0.78, placement.projection.opacity) : placement.projection.opacity * 0.64)
            .position(placement.position)
            .zIndex(planet.id == selectedPlanet.id ? 10 : Double(placement.projection.scale))
        }
    }

    private func shouldShowLabel(for planet: PlanetData, projection: UniverseLabelProjection) -> Bool {
            guard projection.isVisible else { return false }
        switch mode {
        case .overview:
            return planet.id != .core && projection.opacity > 0.28
        case .branchFocus, .toolSelected:
            return planet.id == selectedPlanet.id
        case .detail, .chatOpen:
            return false
        }
    }

    private var toolAnchorLayer: some View {
        GeometryReader { proxy in
            selectedToolAnchor(in: proxy.size)
        }
    }

    private var toolLabelLayer: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ForEach(toolLabelPlacements(in: size)) { placement in
                ToolFloatingLabel(
                    title: placement.tool.name,
                    subtitle: stageShortLabel(placement.tool.stage),
                    color: selectedPlanet.swiftUIColor,
                    isSelected: placement.tool.id == mode.selectedToolID
                )
                .scaleEffect(placement.scale)
                .opacity(placement.opacity)
                .position(placement.position)
                .zIndex(placement.tool.id == mode.selectedToolID ? 12 : Double(placement.scale))
            }
        }
    }

    @ViewBuilder
    private func selectedToolAnchor(in size: CGSize) -> some View {
        if let point = selectedToolScreenPoint(in: size) {
            let cardAnchor = CGPoint(
                x: min(max(point.x, 74), size.width - 74),
                y: size.height - 194
            )
            ToolAnchorBeam(
                from: point,
                to: cardAnchor,
                color: selectedPlanet.swiftUIColor
            )
            ToolAnchorBadge(
                title: selectedTool.name,
                color: selectedPlanet.swiftUIColor
            )
            .position(point)
        }
    }

    private func selectedToolScreenPoint(in size: CGSize) -> CGPoint? {
        guard let toolID = mode.selectedToolID,
              let toolIndex = selectedPlanet.tools.firstIndex(where: { $0.id == toolID }) else {
            return nil
        }
        return toolScreenPoint(selectedPlanet.tools[toolIndex], index: toolIndex, in: size)
    }

    private func toolScreenPoint(_ tool: Tool, index: Int, in size: CGSize) -> CGPoint? {
        let worldPosition: SIMD3<Float>
        if selectedPlanet.id == .core, tool.id == PlanetData.centralCoreToolID {
            // Founder OS is the core planet itself — anchor at its centre.
            worldPosition = selectedPlanet.position3D
        } else {
            worldPosition = UniverseSpatialLayout.satelliteWorldPosition(
                for: tool,
                in: selectedPlanet,
                index: index,
                count: selectedPlanet.tools.count
            )
        }
        let projection = cameraRig.projection(for: worldPosition, in: size)
        guard projection.isVisible else { return nil }
        return projection.point
    }

    private func toolLabelPlacements(in size: CGSize) -> [ToolLabelPlacement] {
        let selectedToolID = mode.selectedToolID
        let candidates = selectedPlanet.tools.enumerated().compactMap { index, tool -> ToolLabelPlacement? in
            // Core's central founder-os has no satellite; it carries the
            // planet label instead.
            if selectedPlanet.id == .core, tool.id == PlanetData.centralCoreToolID {
                return nil
            }
            if mode.showsToolAnchor, tool.id == selectedToolID {
                return nil
            }
            let worldPosition = UniverseSpatialLayout.satelliteWorldPosition(
                for: tool,
                in: selectedPlanet,
                index: index,
                count: selectedPlanet.tools.count
            )
            let projection = cameraRig.projection(for: worldPosition, in: size)
            guard projection.isVisible else { return nil }
            guard projection.opacity > 0.32 || tool.id == selectedToolID else { return nil }

            let position = toolLabelPosition(
                from: projection.point,
                around: selectedPlanet.position3D,
                in: size
            )
            let isSelected = tool.id == selectedToolID
            return ToolLabelPlacement(
                tool: tool,
                projection: projection,
                position: position,
                opacity: isSelected ? 1 : min(0.9, max(0.62, projection.opacity * 0.86)),
                scale: isSelected ? 1.06 : min(1, max(0.82, projection.scale * 0.94))
            )
        }
        .sorted {
            if $0.tool.id == selectedToolID { return true }
            if $1.tool.id == selectedToolID { return false }
            return $0.projection.opacity > $1.projection.opacity
        }

        var placed: [ToolLabelPlacement] = []
        var occupied: [CGRect] = []

        for candidate in candidates {
            guard placed.count < 4 else { break }
            let offsets: [CGSize] = [
                .zero,
                CGSize(width: 0, height: -28),
                CGSize(width: 0, height: 28),
                CGSize(width: -32, height: 0),
                CGSize(width: 32, height: 0),
            ]

            for offset in offsets {
                var next = candidate
                next.position = clampedToolLabelPoint(
                    CGPoint(
                        x: candidate.position.x + offset.width,
                        y: candidate.position.y + offset.height
                    ),
                    in: size
                )
                let rect = toolLabelRect(center: next.position, isSelected: next.tool.id == selectedToolID)
                guard !occupied.contains(where: { $0.intersects(rect) }) else { continue }
                placed.append(next)
                occupied.append(rect)
                break
            }
        }

        return placed
    }

    private func toolLabelPosition(from point: CGPoint, around planetPosition: SIMD3<Float>, in size: CGSize) -> CGPoint {
        let planetProjection = cameraRig.projection(for: planetPosition, in: size)
        var dx = point.x - planetProjection.point.x
        var dy = point.y - planetProjection.point.y
        var length = hypot(dx, dy)
        if length < 12 {
            dx = point.x - size.width * 0.5
            dy = point.y - size.height * 0.42
            length = max(1, hypot(dx, dy))
        }
        return clampedToolLabelPoint(
            CGPoint(
                x: point.x + dx / max(1, length) * 34,
                y: point.y + dy / max(1, length) * 22 - 6
            ),
            in: size
        )
    }

    private func overviewLabelPlacements(in size: CGSize) -> [PlanetLabelPlacement] {
        let candidates = planets.compactMap { planet -> PlanetLabelPlacement? in
            let projection = cameraRig.projection(for: planet.position3D, in: size)
            guard shouldShowLabel(for: planet, projection: projection) else { return nil }
            let coreGuardCenter = CGPoint(x: size.width * 0.5, y: size.height * 0.40)
            if hypot(projection.point.x - coreGuardCenter.x, projection.point.y - coreGuardCenter.y) < 86 {
                return nil
            }
            return PlanetLabelPlacement(
                planet: planet,
                projection: projection,
                position: labelPosition(for: planet, projection: projection, in: size)
            )
        }
        .sorted {
            if $0.planet.id == selectedPlanet.id { return true }
            if $1.planet.id == selectedPlanet.id { return false }
            let leftPriority = overviewLabelPriority(for: $0.planet.id)
            let rightPriority = overviewLabelPriority(for: $1.planet.id)
            if leftPriority != rightPriority {
                return leftPriority < rightPriority
            }
            return $0.projection.opacity > $1.projection.opacity
        }

        var placed: [PlanetLabelPlacement] = []
        var occupied: [CGRect] = []

        for candidate in candidates {
            guard placed.count < 5 else { break }
            let offsets: [CGSize] = [
                .zero,
                CGSize(width: 0, height: -42),
                CGSize(width: 0, height: 42),
                CGSize(width: -34, height: 0),
                CGSize(width: 34, height: 0),
            ]

            for offset in offsets {
                var next = candidate
                next.position = clampedOverviewLabelPoint(
                    CGPoint(
                        x: candidate.position.x + offset.width,
                        y: candidate.position.y + offset.height
                    ),
                    in: size
                )
                let rect = labelRect(center: next.position, isSelected: next.planet.id == selectedPlanet.id)
                guard !occupied.contains(where: { $0.intersects(rect) }) else { continue }
                placed.append(next)
                occupied.append(rect)
                break
            }
        }

        return placed
    }

    private func overviewLabelPriority(for id: ToolCategoryId) -> Int {
        switch id {
        case .media: return 0
        case .coding: return 1
        case .design: return 2
        case .research: return 3
        case .analytics: return 4
        case .infrastructure: return 5
        case .knowledge: return 6
        case .distribution: return 7
        case .core: return 8
        }
    }

    private func labelPosition(for planet: PlanetData, projection: UniverseLabelProjection, in size: CGSize) -> CGPoint {
        let center = CGPoint(x: size.width * 0.5, y: size.height * 0.39)
        var dx = projection.point.x - center.x
        var dy = projection.point.y - center.y
        var length = hypot(dx, dy)

        if length < 42 {
            dx = CGFloat(planet.position3D.x)
            dy = CGFloat(planet.position3D.z) * 0.34 - CGFloat(planet.position3D.y) * 0.56
            length = max(1, hypot(dx, dy))
        }

        let push: CGFloat = planet.id == selectedPlanet.id ? 64 : 46
        let raw = CGPoint(
            x: projection.point.x + dx / max(1, length) * push,
            y: projection.point.y + dy / max(1, length) * push - (planet.id == selectedPlanet.id ? 18 : 6)
        )
        return CGPoint(
            x: min(max(raw.x, 68), size.width - 98),
            y: min(max(raw.y, 98), size.height - 238)
        )
    }

    private func clampedOverviewLabelPoint(_ point: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(
            x: min(max(point.x, 72), size.width - 98),
            y: min(max(point.y, 132), size.height - 292)
        )
    }

    private func labelRect(center: CGPoint, isSelected: Bool) -> CGRect {
        let width: CGFloat = isSelected ? 154 : 130
        let height: CGFloat = isSelected ? 52 : 46
        return CGRect(
            x: center.x - width * 0.5,
            y: center.y - height * 0.5,
            width: width,
            height: height
        )
    }

    private func clampedToolLabelPoint(_ point: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(
            x: min(max(point.x, 70), size.width - 108),
            y: min(max(point.y, 112), size.height - 244)
        )
    }

    private func toolLabelRect(center: CGPoint, isSelected: Bool) -> CGRect {
        let width: CGFloat = isSelected ? 138 : 118
        let height: CGFloat = isSelected ? 42 : 36
        return CGRect(
            x: center.x - width * 0.5,
            y: center.y - height * 0.5,
            width: width,
            height: height
        )
    }

    private func stageShortLabel(_ stage: WorkflowStageId) -> String {
        switch stage {
        case .research: return "Research"
        case .planning: return "Plan"
        case .execution: return "Build"
        case .approval: return "Ship"
        case .review: return "Review"
        }
    }

    private var rightUniverseRail: some View {
        HStack {
            Spacer()
            UniverseRailView(
                categories: railCategories,
                activeCategory: mode.focusedCategory,
                tint: selectedPlanet.swiftUIColor,
                onActiveChange: { isActive in
                    withAnimation(BrandMotion.nudge) {
                        isRailActive = isActive
                    }
                },
                onSelect: onCategorySelect
            )
        }
    }

    private var railCategories: [ToolCategory] {
        let core = UniverseSeed.categories.filter { $0.id == .core }
        let branches = UniverseSeed.categories.filter { $0.id != .core }
        return core + branches
    }

    private var topChrome: some View {
        HStack(alignment: .top, spacing: 12) {
            visualizationControl
                .opacity(mode.isChatOpen || mode.isDetailOpen ? 0.54 : 1)
            Spacer()
            Button(action: onAccount) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white, selectedPlanet.swiftUIColor)
                    .frame(width: 46, height: 46)
                    .liquidGlass(in: Circle(), tint: selectedPlanet.swiftUIColor, strokeStrength: 0.12)
            }
            .buttonStyle(BouncyIconButtonStyle())
            .opacity(mode.isDetailOpen ? 0.58 : 1)
            .accessibilityLabel("Account")
        }
    }

    private var visualizationControl: some View {
        @Bindable var model = model
        return HStack(spacing: 10) {
            Text(model.visualizationStyle.shortLabel)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.black.opacity(0.82))
                .frame(width: 30, height: 30)
                .background(selectedPlanet.swiftUIColor, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(model.visualizationStyle.title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.88))
                    .lineLimit(1)

                Slider(value: styleIndexBinding, in: 0...Double(VisualizationStyle.allCases.count - 1), step: 1)
                    .tint(selectedPlanet.swiftUIColor)
                    .frame(width: 104)
                    .accessibilityLabel("Visualization style")
            }
        }
        .padding(.leading, 8)
        .padding(.trailing, 12)
        .padding(.vertical, 8)
        .liquidGlass(in: Capsule(), tint: selectedPlanet.swiftUIColor.opacity(0.44), strokeStrength: 0.08)
    }

    private var styleIndexBinding: Binding<Double> {
        Binding(
            get: {
                Double(VisualizationStyle.allCases.firstIndex(of: model.visualizationStyle) ?? 0)
            },
            set: { newValue in
                let index = Int(newValue.rounded())
                let styles = VisualizationStyle.allCases
                guard styles.indices.contains(index) else { return }
                let nextStyle = styles[index]
                guard nextStyle != model.visualizationStyle else { return }
                BrandHaptics.fire(.light)
                withAnimation(BrandMotion.flow) {
                    model.visualizationStyle = nextStyle
                }
            }
        )
    }

    private var bottomControls: some View {
        VStack(spacing: 10) {
            if !mode.isDetailOpen && !mode.isChatOpen {
                PlanetInfoCard(
                    planet: selectedPlanet,
                    selectedTool: selectedTool,
                    isFocusedOnTool: isFocusedOnTool,
                    mode: mode,
                    onOpenDetails: onDetails
                )
            }

            if !mode.isDetailOpen {
                SearchDock(
                    onAddTool: onAddTool,
                    onToolSelect: onToolSelect,
                    onChatActivityChange: onChatActivityChange
                )
            }

            if !mode.isDetailOpen && !mode.isChatOpen {
                HStack(alignment: .center, spacing: 6) {
                    CategoryRail { id in
                        onCategorySelect(id)
                    }
                }
            }
        }
    }
}

private struct PlanetLabelPlacement: Identifiable {
    var id: ToolCategoryId { planet.id }
    let planet: PlanetData
    let projection: UniverseLabelProjection
    var position: CGPoint
}

private struct ToolLabelPlacement: Identifiable {
    var id: String { tool.id }
    let tool: Tool
    let projection: UniverseLabelProjection
    var position: CGPoint
    let opacity: Double
    let scale: CGFloat
}

private struct LabelLeaderLine: View {
    let from: CGPoint
    let to: CGPoint
    let color: Color
    let isSelected: Bool

    var body: some View {
        Path { path in
            path.move(to: from)
            let mid = CGPoint(x: (from.x + to.x) * 0.5, y: (from.y + to.y) * 0.5 - 6)
            path.addQuadCurve(to: to, control: mid)
        }
        .stroke(
            color.opacity(isSelected ? 0.58 : 0.28),
            style: StrokeStyle(lineWidth: isSelected ? 1.1 : 0.7, lineCap: .round)
        )
    }
}

private struct ToolAnchorBeam: View {
    let from: CGPoint
    let to: CGPoint
    let color: Color

    var body: some View {
        Path { path in
            path.move(to: from)
            let control = CGPoint(x: from.x, y: (from.y + to.y) * 0.5)
            path.addQuadCurve(to: to, control: control)
        }
        .stroke(
            LinearGradient(
                colors: [color.opacity(0.74), color.opacity(0.08)],
                startPoint: .top,
                endPoint: .bottom
            ),
            style: StrokeStyle(lineWidth: 1.2, lineCap: .round, dash: [4, 7])
        )
        .shadow(color: color.opacity(0.42), radius: 8)
    }
}

private struct ToolAnchorBadge: View {
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
                .shadow(color: color.opacity(0.8), radius: 6)
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(1)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .frame(maxWidth: 138)
        .liquidGlass(in: Capsule(), tint: color.opacity(0.36), strokeStrength: 0.1)
        .shadow(color: color.opacity(0.32), radius: 12)
    }
}

private struct ToolFloatingLabel: View {
    let title: String
    let subtitle: String
    let color: Color
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(color)
                .frame(width: isSelected ? 8 : 6, height: isSelected ? 8 : 6)
                .shadow(color: color.opacity(isSelected ? 0.9 : 0.58), radius: isSelected ? 8 : 5)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: isSelected ? 12 : 10.5, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(isSelected ? 0.98 : 0.86))
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)

                Text(subtitle)
                    .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(isSelected ? 0.72 : 0.62))
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, isSelected ? 7 : 6)
        .frame(width: isSelected ? 126 : 112, alignment: .leading)
        .liquidGlass(in: Capsule(), tint: color.opacity(isSelected ? 0.34 : 0.18), strokeStrength: isSelected ? 0.12 : 0.06)
        .shadow(color: color.opacity(isSelected ? 0.32 : 0.14), radius: isSelected ? 15 : 8)
    }
}

private struct PlanetFloatingLabel: View {
    let title: String
    let subtitle: String
    let color: Color
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 3) {
            Text(title)
                .font(.system(size: isSelected ? 13 : 11, weight: .semibold, design: .rounded))
                .foregroundStyle(BrandColor.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(subtitle)
                .font(.system(size: isSelected ? 10 : 9, weight: .medium, design: .rounded))
                .foregroundStyle(BrandColor.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(width: isSelected ? 128 : 104)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .liquidGlass(in: Capsule(), tint: color.opacity(isSelected ? 0.42 : 0.18), strokeStrength: isSelected ? 0.12 : 0.06)
        .shadow(color: color.opacity(isSelected ? 0.34 : 0.16), radius: isSelected ? 18 : 10)
    }
}
