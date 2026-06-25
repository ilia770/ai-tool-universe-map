import SwiftUI
import simd

struct UniverseOverlayView: View {
    @Environment(UniverseViewModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let planets: [PlanetData]
    let mode: UniverseMode
    let cameraRig: CameraRigController
    let selectedPlanet: PlanetData
    let selectedTool: Tool
    let onCategorySelect: (ToolCategoryId) -> Void
    let onToolSelect: (String) -> Void
    let onOpenToolDetail: (String) -> Void
    let onChatActivityChange: (Bool) -> Void
    let onDetails: () -> Void
    let onAccount: () -> Void
    let onAddTool: () -> Void
    /// §2 morph: namespace (owned by `UniverseMapView`) shared with the Account
    /// and Add Tool sheets so the trigger buttons zoom-morph into them.
    let chromeMorphNamespace: Namespace.ID
    let onAddSuggestedTool: (MissingToolSuggestion) -> Void

    @State private var isRailActive = false
    @Namespace private var chromeNamespace

    private var isFocusedOnTool: Bool {
        guard let selectedToolID = mode.selectedToolID else { return false }
        return selectedTool.id == selectedToolID && selectedTool.category == selectedPlanet.id
    }

    /// Screen-space labels re-project from the camera every render. While the
    /// camera is transitioning OR actively being dragged/pinched, suppress them
    /// so we do not re-project every label on every gesture frame (perf) and so
    /// labels settle around the focus instead of smearing mid-gesture. They
    /// reappear the moment the interaction ends.
    private var labelsQuiescent: Bool {
        !cameraRig.isTransitioning && !cameraRig.isInteracting
    }

    var body: some View {
        ZStack {
            if model.renderMode == .spatial3D && mode.showsPlanetLabels && labelsQuiescent {
                labelLayer
                    .allowsHitTesting(false)
            }

            if model.renderMode == .spatial3D && mode.showsToolAnchor && labelsQuiescent {
                toolAnchorLayer
                    .allowsHitTesting(false)
            }

            if model.renderMode == .spatial3D && mode.showsToolLabels && labelsQuiescent {
                toolLabelLayer
                    .allowsHitTesting(false)
            }

            if isRailActive {
                // RIGHT_RAIL_SPEC: the rail must not cover the map. Constrain the
                // readability treatment to a trailing strip behind the rail/list
                // that fades to clear toward the map, instead of a full-screen scrim.
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    // Frosted dim strip behind the rail text picker: a real material
                    // blur softened by a mask that fades to clear toward the map, so
                    // the readability treatment never covers the map (RIGHT_RAIL_SPEC).
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            LinearGradient(
                                colors: [.clear, Color.black.opacity(0.34)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .mask(
                            LinearGradient(
                                colors: [.clear, .black],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: railContrastWidth)
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .transition(.opacity)
            }

            if model.isUniverseEmpty && !mode.isDetailOpen && !mode.isChatOpen {
                emptyStateCard
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }

            VStack(spacing: 0) {
                if !mode.isDetailOpen && !mode.isChatOpen {
                    topChrome
                        .padding(.horizontal, 16)
                        .padding(.top, 14)

                    if model.renderMode == .spatial3D && !model.isUniverseEmpty {
                        spatialExperimentalNotice
                            .padding(.horizontal, 16)
                            .padding(.top, 10)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }

                Spacer()

                bottomControls
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
            }

            if SpatialChrome.showsMapChrome(renderMode: model.renderMode, mode: mode, isUniverseEmpty: model.isUniverseEmpty) && !cameraRig.isTransitioning {
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
        var byID: [String: ToolLabelPlacement] = [:]
        var rank = 0
        let candidates = selectedPlanet.tools.enumerated().compactMap { index, tool -> LabelPacker.Candidate? in
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
            let isSelected = tool.id == selectedToolID
            guard projection.opacity > 0.32 || isSelected else { return nil }

            let anchor = toolLabelPosition(
                from: projection.point,
                around: selectedPlanet.position3D,
                in: size
            )
            byID[tool.id] = ToolLabelPlacement(
                tool: tool,
                projection: projection,
                position: anchor,
                opacity: isSelected ? 1 : min(0.9, max(0.62, projection.opacity * 0.86)),
                scale: isSelected ? 1.06 : min(1, max(0.82, projection.scale * 0.94))
            )
            // Lower priority value == placed first. Selected wins; others rank
            // by descending opacity (brighter/closer first), made deterministic
            // by a stable enumeration tie-break.
            let priority = isSelected ? Int.min : Int((1 - projection.opacity) * 1000) * 100 + rank
            rank += 1
            return LabelPacker.Candidate(
                id: tool.id,
                anchor: anchor,
                size: toolLabelRect(center: anchor, isSelected: isSelected).size,
                priority: priority,
                pinned: isSelected
            )
        }

        let packed = LabelPacker.pack(
            candidates,
            bounds: CGRect(origin: .zero, size: size),
            safe: toolLabelSafeInsets(),
            maxCount: 4,
            reserved: focusedPlanetLabelRects(in: size)
        )

        return packed.compactMap { placement -> ToolLabelPlacement? in
            guard var resolved = byID[placement.id] else { return nil }
            resolved.position = placement.position
            return resolved
        }
    }

    private func toolLabelSafeInsets() -> LabelPacker.SafeInsets {
        // In 3D mode the experimental notice sits below top chrome; reserve
        // that band so projected labels do not fight the escape hatch.
        LabelPacker.SafeInsets(top: model.renderMode == .spatial3D ? 176 : 112, leading: 70, bottom: 244, trailing: 108)
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
        var byID: [ToolCategoryId: PlanetLabelPlacement] = [:]
        let candidates = planets.compactMap { planet -> LabelPacker.Candidate? in
            let projection = cameraRig.projection(for: planet.position3D, in: size)
            guard shouldShowLabel(for: planet, projection: projection) else { return nil }
            let coreGuardCenter = CGPoint(x: size.width * 0.5, y: size.height * 0.40)
            if hypot(projection.point.x - coreGuardCenter.x, projection.point.y - coreGuardCenter.y) < 86 {
                return nil
            }
            let anchor = labelPosition(for: planet, projection: projection, in: size)
            byID[planet.id] = PlanetLabelPlacement(
                planet: planet,
                projection: projection,
                position: anchor
            )
            let isSelected = planet.id == selectedPlanet.id
            return LabelPacker.Candidate(
                id: planet.id.rawValue,
                anchor: anchor,
                size: labelRect(center: anchor, isSelected: isSelected).size,
                priority: isSelected ? Int.min : overviewLabelPriority(for: planet.id),
                pinned: isSelected
            )
        }

        let packed = LabelPacker.pack(
            candidates,
            bounds: CGRect(origin: .zero, size: size),
            safe: overviewSafeInsets(in: size),
            maxCount: 5
        )

        let center = CGPoint(x: size.width * 0.5, y: size.height * 0.40)
        let centeredID = OverviewLabelFocus.centeredSunID(
            packed.map { p in
                (id: ToolCategoryId(rawValue: p.id), point: p.position)
            },
            screenCenter: center
        )
        return packed.compactMap { placement -> PlanetLabelPlacement? in
            // `ToolCategoryId` is now a non-failable string wrapper; the
            // `byID` lookup filters ids that have no planet. In overview only
            // the centred sun speaks (OverviewLabelFocus).
            let id = ToolCategoryId(rawValue: placement.id)
            guard id == centeredID, var resolved = byID[id] else { return nil }
            resolved.position = placement.position
            return resolved
        }
    }

    private func overviewSafeInsets(in size: CGSize) -> LabelPacker.SafeInsets {
        // Distance from each edge labels must stay inside; mirrors the prior
        // clampedOverviewLabelPoint bounds (top 132, leading 72, trailing 98,
        // bottom 292 to clear the bottom card stack).
        LabelPacker.SafeInsets(top: 132, leading: 72, bottom: 292, trailing: 98)
    }

    private func overviewLabelPriority(for id: ToolCategoryId) -> Int {
        // Lower wins more label space. Built-ins keep their tuned order; custom
        // (user/AI-created) branches sort last so they never displace a seed
        // label, but still appear once seed labels are placed.
        Self.overviewLabelPriorityByCategory[id] ?? 9
    }

    private static let overviewLabelPriorityByCategory: [ToolCategoryId: Int] = [
        .media: 0,
        .coding: 1,
        .design: 2,
        .research: 3,
        .analytics: 4,
        .infrastructure: 5,
        .knowledge: 6,
        .distribution: 7,
        .core: 8,
    ]

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
            y: min(max(raw.y, model.renderMode == .spatial3D ? 162 : 98), size.height - 238)
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

    /// The focused planet label's screen rect in branch/tool mode, so the
    /// tool-label layer can reserve it and not overlap it (cross-layer
    /// de-overlap). Empty when no focused planet label is showing.
    private func focusedPlanetLabelRects(in size: CGSize) -> [CGRect] {
        guard mode.showsPlanetLabels else { return [] }
        let projection = cameraRig.projection(for: selectedPlanet.position3D, in: size)
        guard shouldShowLabel(for: selectedPlanet, projection: projection) else { return [] }
        let center = labelPosition(for: selectedPlanet, projection: projection, in: size)
        return [labelRect(center: center, isSelected: true)]
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

    /// Width of the trailing readability strip behind the active rail. Sized a
    /// little wider than the rail list (184pt) so labels read clearly while the
    /// rest of the map stays uncovered.
    private var railContrastWidth: CGFloat { 220 }

    private var rightUniverseRail: some View {
        HStack {
            Spacer()
            UniverseRailView(
                categories: railCategories,
                activeCategory: mode.focusedCategory,
                tint: selectedPlanet.swiftUIColor,
                onActiveChange: { isActive in
                    withBrandAnimation(BrandMotion.nudge, reduceMotion: reduceMotion) {
                        isRailActive = isActive
                    }
                },
                onSelect: onCategorySelect
            )
        }
    }

    private var railCategories: [ToolCategory] {
        // Only categories that actually have a planet (>=1 tool). Otherwise a
        // sparse universe exposes empty chips that dead-end on tap (ES-1).
        // Sourced from `allCategories` (seed + custom) so user/AI-created
        // branches get rail chips once they hold a tool.
        let present = Set(planets.map(\.id))
        let all = model.allCategories
        let core = all.filter { $0.id == .core && present.contains(.core) }
        let branches = all.filter { $0.id != .core && present.contains($0.id) }
        return core + branches
    }

    private var topChrome: some View {
        Group {
            if #available(iOS 26.0, *) {
                GlassEffectContainer(spacing: 16) {
                    topChromeContent
                }
            } else {
                topChromeContent
            }
        }
        .brandAnimation(BrandMotion.morph, value: mode)
    }

    private var topChromeContent: some View {
        HStack(alignment: .top, spacing: 12) {
            visualizationControl
                .navigationGlassMorphID("UniverseChrome.mode", in: chromeNamespace)
                .opacity(mode.isChatOpen || mode.isDetailOpen ? 0.54 : 1)
            Spacer()
            Button(action: onAccount) {
                UserAvatarImage(size: 46, tint: .white.opacity(0.88))
            }
            .buttonStyle(BouncyIconButtonStyle())
            .navigationGlassMorphID("UniverseChrome.profile", in: chromeNamespace)
            .matchedTransitionSource(id: ChromeMorphID.account, in: chromeMorphNamespace)
            .opacity(mode.isDetailOpen ? 0.58 : 1)
            .accessibilityLabel("Account")
        }
        .transition(.scale(scale: 0.94).combined(with: .opacity))
    }

    private struct RenderModeOption: Identifiable {
        let id: Int
        let title: String
        let icon: String
    }

    /// Selection derives from `model.renderMode`; tapping a slot switches the
    /// mode directly (previously this control mislabelled itself as a viz toggle
    /// but actually opened the Account sheet). 2D stays the cold-start default
    /// (Track A) — this only lets the user opt into 3D and back.
    private var renderModeBinding: Binding<Int> {
        Binding(
            get: { model.renderMode == .graph2D ? 0 : 1 },
            set: { index in
                let target: UniverseRenderMode = index == 0 ? .graph2D : .spatial3D
                guard model.renderMode != target else { return }
                BrandHaptics.fire(.light)
                withBrandAnimation(BrandMotion.flow, reduceMotion: reduceMotion) {
                    model.renderMode = target
                }
            }
        )
    }

    private var visualizationControl: some View {
        GlassMorphCluster(
            options: [
                RenderModeOption(id: 0, title: "2D Graph", icon: "point.3.connected.trianglepath.dotted"),
                RenderModeOption(id: 1, title: "3D Spatial", icon: "cube.transparent"),
            ],
            selection: renderModeBinding,
            base: "universe.renderMode"
        ) { option, isSelected in
            HStack(spacing: BrandSpacing.xs.value) {
                Image(systemName: option.icon).font(.system(size: 11, weight: .bold))
                Text(option.title)
                if option.id == 1, isSelected {
                    Text("Experimental")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.70))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(.white.opacity(0.08), in: Capsule())
                }
            }
        }
        .accessibilityLabel("Visualization mode")
    }

    private var spatialExperimentalNotice: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "cube.transparent")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.72))
                .frame(width: 26, height: 26)
                .background(.white.opacity(0.06), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text("3D Spatial is experimental")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.88))
                Text("Use 2D Graph for daily navigation.")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(BrandColor.textMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Button {
                BrandHaptics.fire(.light)
                withBrandAnimation(BrandMotion.flow, reduceMotion: reduceMotion) {
                    model.renderMode = .graph2D
                }
            } label: {
                Text("Use 2D")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(.white.opacity(0.10), in: Capsule())
                    .overlay {
                        Capsule().stroke(.white.opacity(0.14), lineWidth: 0.5)
                    }
            }
            .buttonStyle(PressableButtonStyle(pressedScale: 0.97, haptic: nil, pressedOpacity: 0.9))
            .accessibilityLabel("Switch to 2D Graph")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: 360)
        .glassSurface(in: RoundedRectangle(cornerRadius: 20, style: .continuous), tint: .white.opacity(0.045), interactive: false)
        .accessibilityElement(children: .contain)
    }

    private var bottomControls: some View {
        VStack(spacing: 10) {
            // Tool card + category rail only make sense once the universe has
            // planets/tools. An empty universe shows the onboarding card instead.
            if SpatialChrome.showsMapChrome(renderMode: model.renderMode, mode: mode, isUniverseEmpty: model.isUniverseEmpty) {
                PlanetInfoCard(
                    planet: selectedPlanet,
                    selectedTool: selectedTool,
                    isFocusedOnTool: isFocusedOnTool,
                    mode: mode,
                    onOpenDetails: onDetails
                )
            }

            if SpatialReveal.showsToolCard(renderMode: model.renderMode, mode: mode) {
                SpatialRevealCard(
                    toolName: selectedTool.name,
                    categoryName: UniverseSeed.category(selectedTool.category).shortName,
                    summary: selectedTool.summary,
                    tint: selectedPlanet.swiftUIColor,
                    onOpen: onDetails
                )
                .parallaxTilt(maxOffset: 6)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            if !mode.isDetailOpen {
                SearchDock(
                    isChatOpen: mode.isChatOpen,
                    onAddTool: onAddTool,
                    onAddSuggestedTool: onAddSuggestedTool,
                    onToolSelect: onToolSelect,
                    onOpenToolDetail: onOpenToolDetail,
                    onChatActivityChange: onChatActivityChange,
                    // When empty, the empty-state card's Add button owns the
                    // morph; opt the composer out so the id isn't duplicated.
                    addToolMorphNamespace: model.isUniverseEmpty ? nil : chromeMorphNamespace
                )
            }

            if SpatialChrome.showsMapChrome(renderMode: model.renderMode, mode: mode, isUniverseEmpty: model.isUniverseEmpty) {
                HStack(alignment: .center, spacing: 6) {
                    CategoryRail { id in
                        onCategorySelect(id)
                    }
                }
            }
        }
        // Gate the reveal spring to 3D: `bottomControls` is shared with the 2D
        // graph (PlanetInfoCard/SearchDock), so an unconditional value would
        // animate 2D content on tool-selection too. In 2D the value is pinned to
        // nil → constant → no implicit animation (keeps the 2D path untouched).
        .brandAnimation(
            BrandMotion.reveal,
            value: SpatialReveal.showsToolCard(renderMode: model.renderMode, mode: mode) ? mode.selectedToolID : nil
        )
    }

    /// Onboarding shown when the universe has no tools yet: the user either adds
    /// their first tool (which becomes the first planet) or loads the bundled
    /// sample universe.
    private var emptyStateCard: some View {
        LiquidGlassCard(cornerRadius: 28) {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(.white.opacity(0.92))
                .accessibilityHidden(true)

            VStack(spacing: 7) {
                Text("Your universe is empty")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .accessibilityAddTraits(.isHeader)
                Text("Add the AI tools you use — each one becomes a planet you can fly between.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.66))
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 10) {
                Button {
                    BrandHaptics.fire(.medium)
                    onAddTool()
                } label: {
                    Label("Add your first tool", systemImage: "plus")
                        .font(.callout.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 30)
                }
                .buttonStyle(PressableButtonStyle(pressedScale: 0.97, haptic: nil, pressedOpacity: 0.9))
                .padding(.vertical, 11)
                .padding(.horizontal, 16)
                .background(.white.opacity(0.14), in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.22), lineWidth: 1))
                .foregroundStyle(.white)
                .matchedTransitionSource(id: ChromeMorphID.addTool, in: chromeMorphNamespace)

                Button {
                    BrandHaptics.fire(.light)
                    onChatActivityChange(true)
                } label: {
                    Label("Ask AI", systemImage: "sparkle")
                        .font(.callout.weight(.medium))
                        .frame(maxWidth: .infinity, minHeight: 30)
                }
                .buttonStyle(PressableButtonStyle(pressedScale: 0.97, haptic: nil, pressedOpacity: 0.9))
                .padding(.vertical, 9)
                .padding(.horizontal, 16)
                .glassSurface(in: Capsule(), interactive: true)
                .foregroundStyle(.white.opacity(0.9))

                Button {
                    BrandHaptics.fire(.light)
                    withBrandAnimation(BrandMotion.flow, reduceMotion: reduceMotion) {
                        _ = model.loadSampleUniverse()
                    }
                } label: {
                    Text("Load a sample universe")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.white.opacity(0.62))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 26)
        .padding(.horizontal, 24)
        .frame(maxWidth: 320)
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
