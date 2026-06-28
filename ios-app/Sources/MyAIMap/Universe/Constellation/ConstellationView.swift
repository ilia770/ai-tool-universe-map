import SwiftUI

/// 2D constellation renderer — the new default map. Tools are stars grouped
/// into category constellations around the Founder OS core. Tapping a star
/// traces its connections (lines draw on with a light pulse) while the
/// connected stars spring/bounce in and the rest dim. Drops into the `graph2D`
/// slot with the same interface as `UniverseGraphView`.
struct ConstellationView: View {
    let planets: [PlanetData]
    let mode: UniverseMode
    let onPlanetTap: @MainActor @Sendable (ToolCategoryId) -> Void
    let onToolTap: @MainActor @Sendable (String) -> Void
    let onEmptyTap: @MainActor @Sendable () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var traceProgress: Double = 0

    private var effectiveReduceMotion: Bool {
        reduceMotion || ProcessInfo.processInfo.arguments.contains("-uitestStatic")
    }

    private var allTools: [Tool] { planets.flatMap(\.tools) }

    /// Connections for the currently selected tool, keyed by target tool id.
    private var connections: [String: ConnectionKind] {
        guard let id = mode.selectedToolID,
              let tool = allTools.first(where: { $0.id == id }) else { return [:] }
        var map: [String: ConnectionKind] = [:]
        for c in ConnectionResolver.connections(for: tool, in: allTools) { map[c.targetID] = c.kind }
        return map
    }

    var body: some View {
        GeometryReader { proxy in
            let layout = ConstellationLayout.make(planets: planets, size: proxy.size)
            let conns = connections
            let hasFocus = mode.selectedToolID != nil
            ZStack {
                background
                    .onTapGesture {
                        guard mode.allowsMapGestures || mode.isChatOpen else { return }
                        onEmptyTap()
                    }
                twinkleLayer(size: proxy.size)
                constellationLayer(layout)
                traceLayer(layout, conns: conns)
                starLayer(layout, conns: conns, hasFocus: hasFocus)
            }
            .contentShape(Rectangle())
            .opacity(mode.mapOpacity)
            .blur(radius: CGFloat(mode.mapBlurRadius))
            .brandAnimation(BrandMotion.flow, value: mode.signature)
            .onChange(of: mode.selectedToolID) { _, newID in
                guard newID != nil else {
                    // Deselect → reverse-draw the trace away.
                    if effectiveReduceMotion { traceProgress = 0 }
                    else { withAnimation(.easeIn(duration: 0.28)) { traceProgress = 0 } }
                    return
                }
                traceProgress = 0
                if effectiveReduceMotion {
                    traceProgress = 1
                } else {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { traceProgress = 1 }
                }
            }
        }
    }

    private var background: some View {
        ZStack {
            BrandColor.void
            RadialGradient(
                colors: [BrandColor.cyan.opacity(0.14), BrandColor.violet.opacity(0.07), .clear],
                center: .center, startRadius: 20, endRadius: 380
            )
        }
        .ignoresSafeArea()
    }

    // Deterministic background twinkle — its own Canvas so the star *buttons*
    // never rebuild on the animation timeline (perf contract).
    @ViewBuilder
    private func twinkleLayer(size: CGSize) -> some View {
        if effectiveReduceMotion || mode.pausesAmbientMotion {
            twinkleCanvas(size: size, phase: 0)
        } else {
            TimelineView(.animation) { timeline in
                twinkleCanvas(size: size, phase: timeline.date.timeIntervalSinceReferenceDate)
            }
        }
    }

    private func twinkleCanvas(size: CGSize, phase: TimeInterval) -> some View {
        Canvas { context, canvasSize in
            for i in 0..<70 {
                let fx = (sin(Double(i) * 12.9898) * 43758.5453).truncatingRemainder(dividingBy: 1)
                let fy = (sin(Double(i) * 78.233) * 12543.1234).truncatingRemainder(dividingBy: 1)
                let x = abs(fx) * canvasSize.width
                let y = abs(fy) * canvasSize.height
                let twinkle = effectiveReduceMotion ? 0.5 : (0.35 + 0.35 * sin(phase * 0.7 + Double(i)))
                let r = 0.6 + Double(i % 3) * 0.4
                context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                             with: .color(.white.opacity(0.10 + 0.18 * twinkle)))
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }

    private func constellationLayer(_ layout: ConstellationLayoutResult) -> some View {
        ZStack {
            Canvas { context, _ in
                for cluster in layout.clusters {
                    let color = UniverseSeed.category(cluster.id).color.swiftUIColor
                    let rect = CGRect(x: cluster.center.x - cluster.radius, y: cluster.center.y - cluster.radius,
                                      width: cluster.radius * 2, height: cluster.radius * 2)
                    let emphasized = cluster.id == mode.focusedCategory
                    context.stroke(Path(ellipseIn: rect.insetBy(dx: -10, dy: -10)),
                                   with: .color(color.opacity(emphasized ? 0.22 : 0.09)),
                                   lineWidth: emphasized ? 1.0 : 0.6)
                }
            }
            .allowsHitTesting(false)

            // Cluster tap targets (behind the star buttons, which sit in a later
            // ZStack layer and win taps that land on a star). Tapping the
            // constellation's empty area focuses that branch.
            ForEach(layout.clusters) { cluster in
                Button {
                    guard mode.allowsMapGestures else { return }
                    onPlanetTap(cluster.id)
                } label: {
                    Color.clear
                        .frame(width: cluster.radius * 2 + 24, height: cluster.radius * 2 + 24)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .position(cluster.center)
                .accessibilityLabel("\(UniverseSeed.category(cluster.id).shortName) constellation")
                .accessibilityIdentifier("ConstellationCategory.\(cluster.id.rawValue)")
            }

            ForEach(layout.clusters) { cluster in
                Text(UniverseSeed.category(cluster.id).shortName)
                    .font(BrandTypography.chip)
                    .foregroundStyle(BrandColor.textMuted.opacity(cluster.id == mode.focusedCategory ? 0.9 : 0.5))
                    .position(x: cluster.center.x, y: cluster.center.y - cluster.radius - 16)
                    .allowsHitTesting(false)
            }
        }
    }

    // Connection lines drawn from the focused star to its connected stars,
    // trimmed to traceProgress with a bright pulse at the drawing head.
    private func traceLayer(_ layout: ConstellationLayoutResult, conns: [String: ConnectionKind]) -> some View {
        Canvas { context, _ in
            guard let id = mode.selectedToolID,
                  let from = layout.stars.first(where: { $0.toolID == id })?.position else { return }
            let starByTool = Dictionary(uniqueKeysWithValues: layout.stars.compactMap { s in s.toolID.map { ($0, s) } })
            let p = max(0, min(traceProgress, 1))
            for (targetID, kind) in conns {
                guard let to = starByTool[targetID]?.position else { continue }
                var path = Path()
                path.move(to: from)
                path.addLine(to: to)
                let trimmed = path.trimmedPath(from: 0, to: p)
                context.stroke(trimmed, with: .color(color(for: kind, selectedCategory: starByTool[id]?.category)),
                               lineWidth: width(for: kind))
                // Pulse head.
                if p > 0.02 && p < 0.99 {
                    let head = CGPoint(x: from.x + (to.x - from.x) * p, y: from.y + (to.y - from.y) * p)
                    context.fill(Path(ellipseIn: CGRect(x: head.x - 2.2, y: head.y - 2.2, width: 4.4, height: 4.4)),
                                 with: .color(.white.opacity(0.95)))
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func color(for kind: ConnectionKind, selectedCategory: ToolCategoryId?) -> Color {
        switch kind {
        case .curated, .ai: return .white.opacity(0.85)
        case .alternative: return (selectedCategory.map { UniverseSeed.category($0).color.swiftUIColor } ?? BrandColor.cyan).opacity(0.8)
        case .pipeline: return BrandColor.cyan.opacity(0.7)
        case .constellation: return .white.opacity(0.22)
        }
    }

    private func width(for kind: ConnectionKind) -> CGFloat {
        switch kind {
        case .curated, .ai: return 1.8
        case .alternative: return 1.5
        case .pipeline: return 1.3
        case .constellation: return 0.7
        }
    }

    private func starLayer(_ layout: ConstellationLayoutResult, conns: [String: ConnectionKind], hasFocus: Bool) -> some View {
        ZStack {
            ForEach(layout.stars) { star in
                let isSelected = star.toolID != nil && star.toolID == mode.selectedToolID
                let isConnected = star.toolID.map { conns[$0] != nil } ?? false
                let role: StarRole = isSelected ? .focused : (isConnected ? .connected : (hasFocus ? .dimmed : .normal))
                StarButton(
                    star: star,
                    role: role,
                    traceProgress: traceProgress,
                    reduceMotion: effectiveReduceMotion,
                    action: {
                        guard mode.allowsMapGestures else { return }
                        if star.isCore { onPlanetTap(.core) }
                        else if let toolID = star.toolID { onToolTap(toolID) }
                    }
                )
                .position(star.position)
                .zIndex(star.isCore ? 30 : (isSelected ? 25 : (isConnected ? 15 : Double(star.radius))))
            }
        }
    }
}

private enum StarRole { case normal, focused, connected, dimmed }

private struct StarButton: View {
    let star: StarNode
    let role: StarRole
    let traceProgress: Double
    let reduceMotion: Bool
    let action: () -> Void

    private var color: Color { UniverseSeed.category(star.category).color.swiftUIColor }
    private var showsLabel: Bool { star.isCore || role == .focused || role == .connected }

    // Connected stars spring/bounce in; the spring's overshoot (traceProgress
    // briefly > 1) makes the scale pop past 1 then settle.
    private var scale: CGFloat {
        guard !reduceMotion else { return role == .focused ? 1.12 : 1 }
        switch role {
        case .focused: return 1.12
        case .connected: return 0.6 + 0.4 * CGFloat(traceProgress)
        case .normal, .dimmed: return 1
        }
    }

    private var bodyOpacity: Double {
        switch role {
        case .dimmed: return 0.3
        default: return 1
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(star.isCore ? BrandColor.core.opacity(0.5) : color.opacity(0.45))
                        .frame(width: star.radius * 3.2, height: star.radius * 3.2)
                        .blur(radius: star.isCore ? 10 : 6)
                        .opacity(role == .focused || role == .connected ? 0.95 : 0.55)
                    Circle()
                        .fill(star.isCore ? AnyShapeStyle(BrandColor.core) : AnyShapeStyle(color))
                        .frame(width: star.radius * 2, height: star.radius * 2)
                        .overlay {
                            Circle().stroke(.white.opacity(star.isCore ? 0.9 : 0.5),
                                            lineWidth: star.isCore ? 1.5 : 0.8)
                        }
                    if star.isCore {
                        Image(systemName: "sparkles")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(BrandColor.void)
                    }
                }
                .scaleEffect(scale)

                if showsLabel {
                    Text(star.title)
                        .font(star.isCore ? BrandTypography.controlLabel : BrandTypography.chip)
                        .foregroundStyle(.white.opacity(role == .focused ? 0.96 : 0.82))
                        .lineLimit(1)
                        .fixedSize()
                }
            }
            .frame(minWidth: max(star.radius * 2, 44), minHeight: max(star.radius * 2, 44))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle(pressedScale: 0.92, haptic: nil, pressedOpacity: 0.92))
        .opacity(bodyOpacity)
        .accessibilityLabel(star.isCore ? "Core, \(star.title)" : "Tool, \(star.title)")
        .accessibilityIdentifier(star.isCore ? "ConstellationStar.core" : "ConstellationStar.\(star.toolID ?? star.id)")
    }
}
