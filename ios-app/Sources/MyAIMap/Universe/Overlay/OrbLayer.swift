import SwiftUI

// MARK: - OrbLayer

/// SwiftUI `Canvas` that renders a set of projected orbs as glowing discs.
///
/// Each orb consists of two passes drawn back-to-front:
///   1. **Halo** — a larger, additive-blended radial gradient disc
///      (category hue → transparent) at scale `OrbStyle.haloScale(_:)`.
///   2. **Core disc** — a radial-gradient filled circle
///      (white core → category hue → transparent rim).
///
/// For the selected orb, the core radius is modulated by
/// `UniverseMotion.pulse(...)` for a ±5 % breathing effect.
///
/// Drawing is purely 2D (no RealityKit). `OrbLayer` is intended to be
/// placed as an overlay on the RealityKit `RealityView` or any container
/// that provides projected screen coordinates via `[ProjectedOrb]`.
struct OrbLayer: View {

    let orbs: [ProjectedOrb]

    // TimelineView injects the date so we can drive the pulse oscillator.
    // The outer view is responsible for wrapping OrbLayer in a
    // TimelineView(.animation) if pulse animation is desired.
    var elapsedSeconds: Float = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Canvas { context, _ in
            // Draw halos first (back layer), then cores (front layer).
            for orb in orbs {
                drawHalo(orb: orb, in: &context)
            }
            for orb in orbs {
                drawCore(orb: orb, in: &context)
            }
        }
        .allowsHitTesting(false)  // OrbLayer is purely visual; taps pass through.
    }

    // MARK: - Halo pass

    private func drawHalo(orb: ProjectedOrb, in context: inout GraphicsContext) {
        let coreR = coreRadius(orb: orb)
        let haloR = coreR * OrbStyle.haloScale(orb.state)
        let em    = OrbStyle.emissive(orb.state)

        // Halo uses the category hue with low opacity for an additive glow feel.
        let haloGradient = Gradient(stops: [
            .init(color: orb.color.opacity(0.28 * em), location: 0.0),
            .init(color: orb.color.opacity(0.10 * em), location: 0.45),
            .init(color: orb.color.opacity(0.0),       location: 1.0),
        ])

        let rect = CGRect(
            x: orb.center.x - haloR,
            y: orb.center.y - haloR,
            width: haloR * 2,
            height: haloR * 2
        )

        context.drawLayer { ctx in
            ctx.blendMode = .screen  // Approximates additive on top of dark backgrounds.
            ctx.fill(
                Path(ellipseIn: rect),
                with: .radialGradient(
                    haloGradient,
                    center: orb.center,
                    startRadius: 0,
                    endRadius: haloR
                )
            )
        }
    }

    // MARK: - Core disc pass

    private func drawCore(orb: ProjectedOrb, in context: inout GraphicsContext) {
        let r  = coreRadius(orb: orb)
        let em = OrbStyle.emissive(orb.state)

        // White-hot centre fading out to the category hue at the rim.
        let coreGradient = Gradient(stops: [
            .init(color: Color.white.opacity(0.92 * em),            location: 0.0),
            .init(color: Color.white.opacity(0.55 * em),            location: 0.20),
            .init(color: orb.color.opacity(0.80 * em),              location: 0.55),
            .init(color: orb.color.opacity(0.0),                    location: 1.0),
        ])

        let rect = CGRect(
            x: orb.center.x - r,
            y: orb.center.y - r,
            width: r * 2,
            height: r * 2
        )

        context.fill(
            Path(ellipseIn: rect),
            with: .radialGradient(
                coreGradient,
                center: orb.center,
                startRadius: 0,
                endRadius: r
            )
        )
    }

    // MARK: - Helpers

    /// Screen radius of the core disc, including pulse for selected orbs.
    private func coreRadius(orb: ProjectedOrb) -> CGFloat {
        let base = OrbStyle.screenRadius(role: orb.role, orbit: orb.orbit, depthScale: orb.depthScale)
        guard orb.state == .selected else { return base }
        let pulse = UniverseMotion.pulse(
            time: elapsedSeconds,
            amplitude: 0.05,
            period: 1.4,
            reduceMotion: reduceMotion
        )
        return base * CGFloat(pulse)
    }
}

// MARK: - Preview

#Preview("OrbLayer — roles") {
    ZStack {
        Color(red: 0.012, green: 0.016, blue: 0.039).ignoresSafeArea()
        TimelineView(.animation) { tl in
            let t = Float(tl.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 100))
            OrbLayer(
                orbs: [
                    ProjectedOrb(
                        center: CGPoint(x: 200, y: 250),
                        depthScale: 1.0,
                        role: .core,
                        orbit: 0,
                        state: .selected,
                        color: .white
                    ),
                    ProjectedOrb(
                        center: CGPoint(x: 120, y: 150),
                        depthScale: 1.0,
                        role: .category,
                        orbit: 1,
                        state: .pocket,
                        color: Color(red: 0.38, green: 0.42, blue: 0.95)
                    ),
                    ProjectedOrb(
                        center: CGPoint(x: 280, y: 160),
                        depthScale: 0.85,
                        role: .tool,
                        orbit: 2,
                        state: .overview,
                        color: Color(red: 0.25, green: 0.82, blue: 0.88)
                    ),
                    ProjectedOrb(
                        center: CGPoint(x: 150, y: 340),
                        depthScale: 0.7,
                        role: .tool,
                        orbit: 3,
                        state: .dimmed,
                        color: Color(red: 0.92, green: 0.36, blue: 0.65)
                    ),
                ],
                elapsedSeconds: t
            )
        }
    }
    .preferredColorScheme(.dark)
}
