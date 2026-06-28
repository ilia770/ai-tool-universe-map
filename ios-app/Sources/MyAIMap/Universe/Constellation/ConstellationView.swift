import SwiftUI

/// 2D constellation renderer — the new default map. Tools are stars grouped
/// into category constellations around the Founder OS core. Drops into the
/// `graph2D` slot with the same interface as `UniverseGraphView`. Connection
/// tracing + the bounce reveal land in the next task; this task is the resting
/// star-field + tap routing.
struct ConstellationView: View {
    let planets: [PlanetData]
    let mode: UniverseMode
    let onPlanetTap: @MainActor @Sendable (ToolCategoryId) -> Void
    let onToolTap: @MainActor @Sendable (String) -> Void
    let onEmptyTap: @MainActor @Sendable () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var effectiveReduceMotion: Bool {
        reduceMotion || ProcessInfo.processInfo.arguments.contains("-uitestStatic")
    }

    var body: some View {
        GeometryReader { proxy in
            let layout = ConstellationLayout.make(planets: planets, size: proxy.size)
            ZStack {
                background
                    .onTapGesture {
                        guard mode.allowsMapGestures || mode.isChatOpen else { return }
                        onEmptyTap()
                    }
                twinkleLayer(size: proxy.size)
                constellationLayer(layout)
                starLayer(layout)
            }
            .contentShape(Rectangle())
            .opacity(mode.mapOpacity)
            .blur(radius: CGFloat(mode.mapBlurRadius))
            .brandAnimation(BrandMotion.flow, value: mode.signature)
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

    // Deterministic background twinkle — tiny static dots whose brightness
    // breathes. Kept in its own Canvas so the star *buttons* never rebuild on
    // the animation timeline (perf contract).
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
            let count = 70
            for i in 0..<count {
                let fx = abs(sin(Double(i) * 12.9898)) .truncatingRemainder(dividingBy: 1)
                let fy = abs(sin(Double(i) * 78.233)) .truncatingRemainder(dividingBy: 1)
                let x = fx * canvasSize.width
                let y = fy * canvasSize.height
                let twinkle = effectiveReduceMotion ? 0.5 : (0.35 + 0.35 * sin(phase * 0.7 + Double(i)))
                let r = 0.6 + (Double(i % 3)) * 0.4
                context.fill(
                    Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                    with: .color(.white.opacity(0.10 + 0.18 * twinkle))
                )
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }

    // Faint constellation outlines + category names so the groupings read.
    private func constellationLayer(_ layout: ConstellationLayoutResult) -> some View {
        ZStack {
            Canvas { context, _ in
                for cluster in layout.clusters {
                    let color = UniverseSeed.category(cluster.id).color.swiftUIColor
                    let rect = CGRect(x: cluster.center.x - cluster.radius,
                                      y: cluster.center.y - cluster.radius,
                                      width: cluster.radius * 2, height: cluster.radius * 2)
                    let emphasized = cluster.id == mode.focusedCategory
                    context.stroke(
                        Path(ellipseIn: rect.insetBy(dx: -10, dy: -10)),
                        with: .color(color.opacity(emphasized ? 0.22 : 0.09)),
                        lineWidth: emphasized ? 1.0 : 0.6
                    )
                }
            }
            .allowsHitTesting(false)

            ForEach(layout.clusters) { cluster in
                Text(UniverseSeed.category(cluster.id).shortName)
                    .font(BrandTypography.chip)
                    .foregroundStyle(BrandColor.textMuted.opacity(cluster.id == mode.focusedCategory ? 0.9 : 0.5))
                    .position(x: cluster.center.x, y: cluster.center.y - cluster.radius - 16)
                    .allowsHitTesting(false)
            }
        }
    }

    private func starLayer(_ layout: ConstellationLayoutResult) -> some View {
        ZStack {
            ForEach(layout.stars) { star in
                StarButton(
                    star: star,
                    isSelected: star.toolID != nil && star.toolID == mode.selectedToolID,
                    isContext: star.category == mode.focusedCategory,
                    reduceMotion: effectiveReduceMotion,
                    action: {
                        guard mode.allowsMapGestures else { return }
                        if star.isCore {
                            onPlanetTap(.core)
                        } else if let toolID = star.toolID {
                            onToolTap(toolID)
                        }
                    }
                )
                .position(star.position)
                .zIndex(star.isCore ? 30 : (star.toolID == mode.selectedToolID ? 20 : Double(star.radius)))
            }
        }
    }
}

private struct StarButton: View {
    let star: StarNode
    let isSelected: Bool
    let isContext: Bool
    let reduceMotion: Bool
    let action: () -> Void

    private var color: Color { UniverseSeed.category(star.category).color.swiftUIColor }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    // Glow.
                    Circle()
                        .fill(star.isCore ? BrandColor.core.opacity(0.5) : color.opacity(0.45))
                        .frame(width: star.radius * 3.2, height: star.radius * 3.2)
                        .blur(radius: star.isCore ? 10 : 6)
                        .opacity(isSelected ? 0.95 : 0.6)
                    // Star body.
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
                .scaleEffect(isSelected && !reduceMotion ? 1.14 : 1)

                if star.isCore {
                    Text(star.title)
                        .font(BrandTypography.controlLabel)
                        .foregroundStyle(.white.opacity(0.92))
                        .lineLimit(1)
                }
            }
            .frame(minWidth: max(star.radius * 2, 44), minHeight: max(star.radius * 2, 44))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle(pressedScale: 0.92, haptic: nil, pressedOpacity: 0.92))
        .accessibilityLabel(star.isCore ? "Core, \(star.title)" : "Tool, \(star.title)")
        .accessibilityIdentifier(star.isCore ? "ConstellationStar.core" : "ConstellationStar.\(star.toolID ?? star.id)")
    }
}
