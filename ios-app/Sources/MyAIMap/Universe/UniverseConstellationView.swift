import SwiftUI

/// Premium 2D-first universe renderer.
///
/// The map is intentionally a deterministic constellation, not a pseudo-3D
/// scene: branch/tool identity stays readable, taps are normal SwiftUI buttons,
/// and motion comes from springy node seating rather than camera gymnastics.
struct UniverseConstellationView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let planets: [PlanetData]
    let mode: UniverseMode
    let onPlanetTap: (ToolCategoryId) -> Void
    let onToolTap: (String) -> Void
    let onEmptyTap: () -> Void

    @State private var breath = false
    @State private var requestedToolPageIndex = 0

    private var staticMotion: Bool {
        reduceMotion || ProcessInfo.processInfo.arguments.contains("-uitestStatic")
    }

    private var ambientMotionEnabled: Bool {
        !staticMotion && !mode.pausesAmbientMotion
    }

    var body: some View {
        GeometryReader { proxy in
            let layout = UniverseConstellationLayout.make(
                planets: planets,
                mode: mode,
                size: proxy.size,
                requestedToolPageIndex: requestedToolPageIndex
            )
            let planetsByID = Dictionary(uniqueKeysWithValues: planets.map { ($0.id, $0) })

            ZStack {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard mode.allowsMapGestures else { return }
                        onEmptyTap()
                    }

                ConstellationBackdrop(layout: layout, planetsByID: planetsByID, breath: breath && ambientMotionEnabled)
                    .allowsHitTesting(false)

                constellationNodes(layout: layout, planetsByID: planetsByID)

                if let toolPage = layout.toolPage,
                   toolPage.isPaginated,
                   mode.selectedToolID == nil,
                   mode.allowsMapGestures {
                    constellationPager(toolPage)
                        .position(
                            x: proxy.size.width / 2,
                            y: UniverseConstellationLayout.contentRect(in: proxy.size).maxY - 16
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .opacity(mode.mapOpacity)
            .blur(radius: mode.mapBlurRadius)
            .brandAnimation(BrandMotion.morph, value: mode.signature)
            .onAppear {
                startBreathingIfAllowed()
                preserveSelectedToolPage(layout.toolPage)
            }
            .onChange(of: mode.pausesAmbientMotion) { _, pausesAmbientMotion in
                if pausesAmbientMotion {
                    breath = false
                } else {
                    startBreathingIfAllowed()
                }
            }
            .onChange(of: mode.focusedCategory) { _, _ in
                requestedToolPageIndex = 0
            }
            .onChange(of: mode.selectedToolID) { _, _ in
                preserveSelectedToolPage(layout.toolPage)
            }
        }
    }

    private func constellationPager(_ toolPage: UniverseConstellationLayout.ToolPage) -> some View {
        HStack(spacing: BrandSpacing.m.value) {
            Button {
                requestedToolPageIndex -= 1
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 44, height: 44)
            }
            .disabled(!toolPage.hasPreviousPage)
            .accessibilityLabel("Previous tools page")
            .accessibilityIdentifier("ConstellationPager.Previous")

            Text("Tools \(toolPage.index + 1) of \(toolPage.count)")
                .font(BrandTypography.graphMetadata.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(BrandColor.textPrimary)
                .accessibilityLabel("Tools page \(toolPage.index + 1) of \(toolPage.count), \(toolPage.totalToolCount) tools")

            Button {
                requestedToolPageIndex += 1
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 44, height: 44)
            }
            .disabled(!toolPage.hasNextPage)
            .accessibilityLabel("Next tools page")
            .accessibilityIdentifier("ConstellationPager.Next")
        }
        .buttonStyle(PressableButtonStyle(pressedScale: 0.94, haptic: .light, pressedOpacity: 0.92))
        .padding(.horizontal, BrandSpacing.m.value)
        .padding(.vertical, BrandSpacing.s.value)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.16), lineWidth: 0.75))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("ConstellationPager")
    }

    private func preserveSelectedToolPage(_ toolPage: UniverseConstellationLayout.ToolPage?) {
        guard mode.selectedToolID != nil, let toolPage else { return }
        requestedToolPageIndex = toolPage.index
    }

    @ViewBuilder
    private func constellationNodes(
        layout: UniverseConstellationLayout.Layout,
        planetsByID: [ToolCategoryId: PlanetData]
    ) -> some View {
        nodeStack(layout: layout, planetsByID: planetsByID)
    }

    private func nodeStack(
        layout: UniverseConstellationLayout.Layout,
        planetsByID: [ToolCategoryId: PlanetData]
    ) -> some View {
        ZStack {
            if let corePoint = layout.corePoint,
               let core = planetsByID[.core],
               mode == .overview || mode.isChatOpen {
                ConstellationCoreNode(planet: core, breath: breath && ambientMotionEnabled)
                    .position(corePoint)
                    .transition(.scale(scale: 0.82).combined(with: .opacity))
            }

            ForEach(layout.categoryNodes) { node in
                if let planet = planetsByID[node.categoryID] {
                    categoryNodeButton(node: node, planet: planet)
                        .position(node.point)
                        .zIndex(node.isFocused ? 20 : node.isContext ? 2 : 8)
                }
            }

            ForEach(layout.toolNodes) { node in
                if let planet = planetsByID[node.categoryID] {
                    toolNodeButton(node: node, planet: planet)
                        .position(node.point)
                        .zIndex(node.isSelected ? 30 : Double(10 - min(node.priority, 8)))
                }
            }
        }
    }

    private func categoryNodeButton(
        node: UniverseConstellationLayout.CategoryNode,
        planet: PlanetData
    ) -> some View {
        Button {
            guard mode.allowsMapGestures else { return }
            onPlanetTap(node.categoryID)
        } label: {
            ConstellationCategoryNode(
                title: planet.title,
                subtitle: node.isFocused ? Pluralize.count(planet.toolCount, "tool") : nil,
                color: planet.swiftUIColor,
                diameter: node.diameter,
                isFocused: node.isFocused,
                isContext: node.isContext,
                breath: breath && ambientMotionEnabled
            )
        }
        .buttonStyle(PressableButtonStyle(pressedScale: 0.97, haptic: nil, pressedOpacity: 0.96))
        .hitArea()
        .disabled(!mode.allowsMapGestures)
        .accessibilityLabel("Category node, \(planet.title), \(Pluralize.count(planet.toolCount, "tool"))")
        .accessibilityIdentifier("ConstellationCategory.\(node.categoryID.rawValue)")
    }

    private func toolNodeButton(
        node: UniverseConstellationLayout.ToolNode,
        planet: PlanetData
    ) -> some View {
        Button {
            guard mode.allowsMapGestures else { return }
            onToolTap(node.toolID)
        } label: {
            ConstellationToolNode(
                title: node.title,
                subtitle: stageShortLabel(node.stage),
                color: planet.swiftUIColor,
                diameter: node.diameter,
                isSelected: node.isSelected,
                breath: breath && ambientMotionEnabled
            )
        }
        .buttonStyle(PressableButtonStyle(pressedScale: 0.97, haptic: nil, pressedOpacity: 0.96))
        .disabled(!mode.allowsMapGestures)
        .accessibilityLabel("Tool node, \(node.title), \(stageShortLabel(node.stage))")
        .accessibilityIdentifier("ConstellationStar.\(node.toolID)")
        .background {
            if node.isSelected {
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: ToolFlightTargetPreferenceKey.self,
                        value: ToolFlightTarget(
                            toolID: node.toolID,
                            frame: proxy.frame(in: .named(RootShellCoordinateSpace.name))
                        )
                    )
                }
            }
        }
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

    private func startBreathingIfAllowed() {
        guard ambientMotionEnabled else {
            breath = false
            return
        }
        withAnimation(BrandMotion.breath) {
            breath = true
        }
    }
}

private struct ConstellationBackdrop: View {
    let layout: UniverseConstellationLayout.Layout
    let planetsByID: [ToolCategoryId: PlanetData]
    let breath: Bool

    var body: some View {
        Canvas { context, _ in
            for edge in layout.edges {
                let color = planetsByID[edge.categoryID]?.swiftUIColor ?? BrandColor.core
                var path = Path()
                path.move(to: edge.from)
                let control = CGPoint(
                    x: (edge.from.x + edge.to.x) * 0.5,
                    y: min(edge.from.y, edge.to.y) - BrandSpacing.xl.value
                )
                path.addQuadCurve(to: edge.to, control: control)
                context.stroke(
                    path,
                    with: .color(color.opacity(edge.isStrong ? 0.56 : 0.18)),
                    style: StrokeStyle(
                        lineWidth: edge.isStrong ? 1.35 : 0.75,
                        lineCap: .round,
                        dash: edge.isStrong ? [] : [3, 8]
                    )
                )
            }
        }
        .opacity(breath ? 1 : 0.72)
    }
}

private struct ConstellationCoreNode: View {
    let planet: PlanetData
    let breath: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(planet.swiftUIColor.opacity(0.06))
                .frame(width: 92, height: 92)
                .scaleEffect(breath ? 1.08 : 1)
            Circle()
                .fill(BrandColor.card)
                .frame(width: 64, height: 64)
                .overlay { Circle().fill(planet.swiftUIColor.opacity(0.08)) }
                .overlay { Circle().stroke(planet.swiftUIColor.opacity(0.22), lineWidth: 0.75) }
            Circle()
                .fill(planet.swiftUIColor)
                .frame(width: 14, height: 14)
                .shadow(color: planet.swiftUIColor.opacity(0.62), radius: 12)
        }
        .overlay {
            Text("Founder OS")
                .font(BrandTypography.graphCoreLabel)
                .foregroundStyle(BrandColor.textPrimary)
                .lineLimit(1)
                .fixedSize()
                .offset(y: 92 / 2 + BrandSpacing.xl.value)
        }
        .allowsHitTesting(false)
    }
}

private struct ConstellationCategoryNode: View {
    let title: String
    let subtitle: String?
    let color: Color
    let diameter: CGFloat
    let isFocused: Bool
    let isContext: Bool
    let breath: Bool

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(isFocused ? 0.38 : 0.20), lineWidth: isFocused ? 1.4 : 0.8)
                .frame(width: diameter + (isFocused ? 18 : 10), height: diameter + (isFocused ? 18 : 10))
                .scaleEffect(isFocused && breath ? 1.08 : 1)
            Circle()
                .fill(BrandColor.card)
                .frame(width: diameter, height: diameter)
                .overlay { Circle().fill(color.opacity(isFocused ? 0.16 : 0.10)) }
                .overlay { Circle().stroke(color.opacity(isFocused ? 0.34 : 0.18), lineWidth: 0.75) }

            if isContext {
                Circle()
                    .fill(color)
                    .frame(width: 7, height: 7)
                    .shadow(color: color.opacity(0.44), radius: 7)
            } else {
                Circle()
                    .fill(color)
                    .frame(width: isFocused ? 11 : 9, height: isFocused ? 11 : 9)
                    .shadow(color: color.opacity(isFocused ? 0.64 : 0.42), radius: isFocused ? 10 : 7)
            }
        }
        .overlay {
            if !isContext {
                VStack(spacing: BrandSpacing.hair.value) {
                    Text(title)
                        .font(isFocused ? BrandTypography.graphLabelFocused : BrandTypography.graphLabel)
                        .foregroundStyle(isFocused ? BrandColor.textPrimary : BrandColor.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                    if let subtitle {
                        Text(subtitle)
                            .font(BrandTypography.graphMetadata)
                            .foregroundStyle(BrandColor.textMuted)
                            .lineLimit(1)
                    }
                }
                .frame(width: isFocused ? 112 : 88)
                .fixedSize(horizontal: false, vertical: true)
                .offset(y: labelOffset)
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    private var labelOffset: CGFloat {
        diameter / 2 + (isFocused ? BrandSpacing.section.value : BrandSpacing.xl.value)
    }
}

private struct ConstellationToolNode: View {
    let title: String
    let subtitle: String
    let color: Color
    let diameter: CGFloat
    let isSelected: Bool
    let breath: Bool

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(isSelected ? 0.42 : 0.18), lineWidth: isSelected ? 1.4 : 0.8)
                .frame(width: diameter + (isSelected ? 18 : 10), height: diameter + (isSelected ? 18 : 10))
                .scaleEffect(isSelected && breath ? 1.10 : 1)
            Circle()
                .fill(BrandColor.card)
                .frame(width: diameter, height: diameter)
                .overlay { Circle().fill(color.opacity(isSelected ? 0.14 : 0.07)) }
                .overlay { Circle().stroke(color.opacity(isSelected ? 0.30 : 0.16), lineWidth: 0.75) }
            Circle()
                .fill(color)
                .frame(width: isSelected ? 11 : 7, height: isSelected ? 11 : 7)
                .shadow(color: color.opacity(isSelected ? 0.66 : 0.38), radius: isSelected ? 10 : 6)
        }
        .overlay {
            VStack(spacing: BrandSpacing.hair.value) {
                Text(title)
                    .font(isSelected ? BrandTypography.graphLabelFocused : BrandTypography.graphToolLabel)
                    .foregroundStyle(isSelected ? BrandColor.textPrimary : BrandColor.textSecondary)
                    .lineLimit(isSelected ? 2 : 1)
                    .multilineTextAlignment(.center)
                if isSelected {
                    Text(subtitle)
                        .font(BrandTypography.graphMetadata)
                        .foregroundStyle(BrandColor.textMuted)
                        .lineLimit(1)
                }
            }
            .frame(width: isSelected ? 104 : 84)
            .fixedSize(horizontal: false, vertical: true)
            .offset(y: diameter / 2 + (isSelected ? BrandSpacing.section.value : BrandSpacing.xl.value))
        }
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
}
