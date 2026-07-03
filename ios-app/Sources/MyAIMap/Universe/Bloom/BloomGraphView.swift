import OSLog
import SwiftUI

/// Perf instrumentation only — inert unless an Instruments trace is running.
private let signposter = OSSignposter(subsystem: "com.iliaturilia.myaimap", category: "bloom")

/// Bloom graph (variant K) — the new 2D map. Starts at Founder OS; tapping a
/// node blooms its connections outward on a radial fan and dims the rest; tap
/// again to collapse. Plain curved connection lines (no arrowheads). Drops into
/// the `graph2D` slot with the same interface as the other renderers.
struct BloomGraphView: View {
    let planets: [PlanetData]
    let mode: UniverseMode
    let onPlanetTap: @MainActor @Sendable (ToolCategoryId) -> Void
    let onToolTap: @MainActor @Sendable (String) -> Void
    let onEmptyTap: @MainActor @Sendable () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var engine: BloomEngine?

    // Graph model, derived from the tool set. These only change when the tool
    // set changes — NOT every frame — so they're memoized in @State and rebuilt
    // via `.onAppear` / `.onChange(of: toolIDs)` instead of recomputed inside the
    // per-frame TimelineView/Canvas render pass.
    @State private var allTools: [Tool] = []
    @State private var toolByID: [String: Tool] = [:]
    @State private var adjacency: [String: [String]] = [:]
    @State private var allEdges: [(a: String, b: String)] = []

    private var reduced: Bool {
        reduceMotion || ProcessInfo.processInfo.arguments.contains("-uitestStatic")
    }

    /// Cheap, stable signature of the tool set (order-sensitive, matches how the
    /// model is derived). Drives `.onChange` so the model rebuilds only when the
    /// tools actually change.
    private var toolIDs: [String] { planets.flatMap { $0.tools.map(\.id) } }

    private func rebuildModel() {
        let tools = planets.flatMap(\.tools)
        allTools = tools
        toolByID = Dictionary(tools.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        adjacency = BloomAdjacency.build(tools: tools)
        allEdges = BloomAdjacency.edges(tools: tools)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                background
                    .onTapGesture { if mode.allowsMapGestures { onEmptyTap() } }

                if let engine {
                    graphCanvas(engine: engine, size: proxy.size)
                        .gesture(tapGesture(engine: engine, size: proxy.size))
                    breadcrumbBar(engine: engine)
                }
            }
            .opacity(mode.mapOpacity)
            .blur(radius: CGFloat(mode.mapBlurRadius))
            .onAppear { rebuildModel(); ensureEngine() }
            .onChange(of: toolIDs) { _, _ in rebuildModel() }
        }
    }

    private func ensureEngine() {
        guard engine == nil else { return }
        let adj = adjacency
        let seed = allTools.contains(where: { $0.id == PlanetData.centralCoreToolID })
            ? PlanetData.centralCoreToolID
            : (allTools.first?.id ?? "")
        let e = BloomEngine(adjacency: adj, seedID: seed)
        // Pre-expand a tool for simctl screenshots (the sim is too flaky for
        // XCUITest taps). Reveals the seed → tool path, then blooms the tool.
        let args = ProcessInfo.processInfo.arguments
        if let idx = args.firstIndex(of: "-uitestFocusTool"), idx + 1 < args.count {
            let target = args[idx + 1]
            if e.revealed.contains(target) { e.expand(target) }
            else if let via = (adj[target] ?? []).first(where: { e.revealed.contains($0) }) {
                e.expand(via); e.expand(target)
            }
        }
        engine = e
    }

    private var background: some View {
        ZStack {
            BrandColor.void
            RadialGradient(colors: [Color(red: 0.04, green: 0.07, blue: 0.13), BrandColor.void],
                           center: .top, startRadius: 0, endRadius: 700)
        }
        .ignoresSafeArea()
    }

    private func graphCanvas(engine: BloomEngine, size: CGSize) -> some View {
        TimelineView(.animation) { _ in
            tickedCanvas(engine: engine, size: size)
        }
    }

    /// Plain function (not a ViewBuilder) so the tick loop is legal, then returns
    /// the freshly-drawn Canvas. Extra sub-steps under reduce-motion settle the
    /// spring fast so a static capture isn't mid-flight.
    private func tickedCanvas(engine: BloomEngine, size: CGSize) -> some View {
        let steps = reduced ? 10 : 1
        for _ in 0..<steps {
            engine.tick(dt: 1.0 / 60, reduced: reduced, allEdges: allEdges)
        }
        return Canvas { ctx, _ in
            draw(engine: engine, size: size, ctx: &ctx)
        }
    }

    private func worldToScreen(_ x: Double, _ y: Double, engine: BloomEngine, size: CGSize) -> CGPoint {
        CGPoint(x: x - engine.camX + Double(size.width) / 2,
                y: y - engine.camY + Double(size.height) / 2 + 12)
    }

    private func draw(engine: BloomEngine, size: CGSize, ctx: inout GraphicsContext) {
        let signpostState = signposter.beginInterval("bloom.layout")
        defer { signposter.endInterval("bloom.layout", signpostState) }

        let focusID = engine.focusID
        let revealed = engine.revealed
        let neighboursOfFocus = Set(adjacency[focusID] ?? []).intersection(revealed)
        let activeSet = neighboursOfFocus.union([focusID])

        // Edges (plain curved lines, no arrowheads).
        for e in engine.visibleEdges(allEdges) {
            guard let a = engine.nodes[e.a], let b = engine.nodes[e.b] else { continue }
            let pa = worldToScreen(a.x, a.y, engine: engine, size: size)
            let pb = worldToScreen(b.x, b.y, engine: engine, size: size)
            let touchesFocus = e.a == focusID || e.b == focusID
            let hasFocusActive = !activeSet.isEmpty && activeSet.count < revealed.count
            // Trim to node rim.
            let dx = pb.x - pa.x, dy = pb.y - pa.y
            let len = max(hypot(dx, dy), 0.001)
            let ux = dx / len, uy = dy / len
            let trim = BloomEngine.nodeRadius
            let s = CGPoint(x: pa.x + ux * trim, y: pa.y + uy * trim)
            let t = CGPoint(x: pb.x - ux * trim, y: pb.y - uy * trim)
            let mx = (s.x + t.x) / 2 - uy * 20, my = (s.y + t.y) / 2 + ux * 20
            var path = Path()
            path.move(to: s)
            path.addQuadCurve(to: t, control: CGPoint(x: mx, y: my))
            let color: Color
            let width: CGFloat
            if touchesFocus {
                color = categoryColor(e.a == focusID ? e.b : e.a).opacity(0.9); width = 2.2
            } else if hasFocusActive {
                color = Color(red: 0.34, green: 0.42, blue: 0.52).opacity(0.18); width = 1.0
            } else {
                color = Color(red: 0.36, green: 0.42, blue: 0.52).opacity(0.55); width = 1.1
            }
            ctx.stroke(path, with: .color(color), lineWidth: width)
        }

        // Nodes.
        for (id, node) in engine.nodes {
            guard let tool = toolByID[id] else { continue }
            let p = worldToScreen(node.x, node.y, engine: engine, size: size)
            let isFocus = id == focusID
            let dim = (!activeSet.isEmpty && activeSet.count < revealed.count && !activeSet.contains(id)) ? 0.22 : 1.0
            let ease = node.appear * node.appear * (3 - 2 * node.appear)
            let scale = ease * (isFocus ? 1.2 : 1)
            let r = BloomEngine.nodeRadius * scale
            let color = categoryColor(id)

            // Focus halo.
            if isFocus {
                ctx.stroke(Path(ellipseIn: CGRect(x: p.x - r - 11, y: p.y - r - 11, width: (r + 11) * 2, height: (r + 11) * 2)),
                           with: .color(color.opacity(0.5)), lineWidth: 2)
            }
            // Expand/collapse affordance ring.
            if engine.hasHidden(id) {
                ctx.stroke(Path(ellipseIn: CGRect(x: p.x - r - 5, y: p.y - r - 5, width: (r + 5) * 2, height: (r + 5) * 2)),
                           with: .color(color.opacity(0.7 * dim)),
                           style: StrokeStyle(lineWidth: 1.4, dash: [3, 5]))
            }
            // Body: translucent shell + inner solid dot.
            let bodyRect = CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)
            ctx.fill(Path(ellipseIn: bodyRect), with: .color(color.opacity(0.16 * dim)))
            ctx.stroke(Path(ellipseIn: bodyRect), with: .color(color.opacity(dim)), lineWidth: isFocus ? 2.6 : 1.6)
            let inner = r * 0.42
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - inner, y: p.y - inner, width: inner * 2, height: inner * 2)),
                     with: .color(color.opacity(0.9 * dim)))

            // Label pill.
            if scale > 0.5 {
                let text = Text(tool.name).font(.system(size: 11, weight: .semibold)).foregroundColor(.white.opacity(dim))
                let resolved = ctx.resolve(text)
                let tsize = resolved.measure(in: CGSize(width: 160, height: 30))
                let pillW = tsize.width + 16, pillH: CGFloat = 20
                let pill = CGRect(x: p.x - pillW / 2, y: p.y + r + 6, width: pillW, height: pillH)
                ctx.fill(Path(roundedRect: pill, cornerRadius: 10), with: .color(Color(red: 0.04, green: 0.07, blue: 0.13).opacity(0.85 * dim)))
                ctx.stroke(Path(roundedRect: pill, cornerRadius: 10), with: .color(color.opacity((isFocus ? 0.8 : 0.45) * dim)), lineWidth: 1)
                ctx.draw(resolved, at: CGPoint(x: pill.midX, y: pill.midY), anchor: .center)
            }
        }
    }

    private func tapGesture(engine: BloomEngine, size: CGSize) -> some Gesture {
        SpatialTapGesture().onEnded { value in
            guard mode.allowsMapGestures else { return }
            // Find nearest revealed node within its hit radius.
            var best: (id: String, d: CGFloat)? = nil
            for (id, node) in engine.nodes where !node.collapsing {
                let p = worldToScreen(node.x, node.y, engine: engine, size: size)
                let d = hypot(value.location.x - p.x, value.location.y - p.y)
                let hit = max(BloomEngine.nodeRadius + 14, 26)
                if d <= hit && (best == nil || d < best!.d) { best = (id, d) }
            }
            if let best {
                engine.tap(best.id)
                onToolTap(best.id)
            } else {
                onEmptyTap()
            }
        }
    }

    private func breadcrumbBar(engine: BloomEngine) -> some View {
        VStack {
            HStack(spacing: 6) {
                ForEach(Array(engine.breadcrumb.enumerated()), id: \.offset) { idx, id in
                    if idx > 0 { Text("›").font(.caption2).foregroundStyle(BrandColor.textMuted) }
                    Button {
                        engine.collapseTo(stepCount: idx + 1)
                        onToolTap(id)
                    } label: {
                        Text(toolByID[id]?.name ?? id)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(idx == engine.breadcrumb.count - 1 ? .white : BrandColor.textMuted)
                            .lineLimit(1)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(.white.opacity(0.06), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.horizontal, BrandSpacing.l.value)
            .padding(.top, 150)
            Spacer()
        }
    }

    private func categoryColor(_ toolID: String) -> Color {
        guard let tool = toolByID[toolID] else { return BrandColor.cyan }
        return UniverseSeed.category(tool.category).color.swiftUIColor
    }
}
