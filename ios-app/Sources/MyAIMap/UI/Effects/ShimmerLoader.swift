import SwiftUI

/// Animated shimmer for any placeholder. Use as the loading state
/// while the Liquid Glass intake field is classifying, or while the
/// universe data is hydrating.
///
/// Usage:
///
/// ```swift
/// RoundedRectangle(cornerRadius: BrandRadius.card.value)
///   .fill(BrandColor.muted)
///   .shimmer()
///   .frame(height: 24)
/// ```
extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

private struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { proxy in
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: .clear, location: 0),
                            .init(color: BrandColor.white.opacity(0.12), location: 0.5),
                            .init(color: .clear, location: 1),
                        ]),
                        startPoint: UnitPoint(x: phase, y: 0.5),
                        endPoint: UnitPoint(x: phase + 0.4, y: 0.5)
                    )
                    .blendMode(.overlay)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                }
                .allowsHitTesting(false)
            }
            .mask(content)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
                    phase = 1.4
                }
            }
    }
}

/// Progress orb — a single pulsing dot that doubles as the boot
/// indicator before the RealityKit scene has any geometry on screen.
/// Visually loud enough to feel intentional, quiet enough to fade out
/// fast when the scene is ready.
struct ProgressOrb: View {
    var color: Color = BrandColor.core
    var size: CGFloat = 14

    @State private var pulse: CGFloat = 0.86
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .shadow(color: color.opacity(0.55), radius: size * 1.4)
            .scaleEffect(pulse)
            .opacity(reduceMotion ? 0.8 : 0.65)
            .onAppear {
                guard !reduceMotion else { return }
                withBrandAnimation(BrandMotion.breath, reduceMotion: reduceMotion) {
                    pulse = 1.18
                }
            }
            .accessibilityLabel("Loading universe")
    }
}
