import SwiftUI

/// Pure boot-phase gate for the Universe scene. Starts in `.loading` so the
/// very first paint is the branded loader (not a black RealityKit frame), and
/// flips to `.ready` once the scene's first frame is up. Plain `Sendable`
/// value type (no actor isolation) so it stays Swift 6.0-clean and headless-
/// testable.
struct UniverseBootState: Sendable, Equatable {
    enum Phase: Sendable, Equatable {
        case loading
        case ready
    }

    private(set) var phase: Phase = .loading

    /// Flip to `.ready` once the scene is on screen. Idempotent.
    mutating func markSceneReady() {
        phase = .ready
    }
}

/// Branded cold-launch loader. Fills the void with the app's space color and a
/// pulsing `ProgressOrb`, killing the black frame between app launch and the
/// RealityKit scene's first paint. Reuses `ShimmerLoader`'s `ProgressOrb` +
/// `.shimmer()`; honors Reduce Motion (both are gated internally).
struct UniverseLoadingView: View {
    var body: some View {
        ZStack {
            BrandColor.void.ignoresSafeArea()
            VStack(spacing: BrandSpacing.m.value) {
                ProgressOrb(size: 18)
                Text("My AI Map")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.55))
                    .shimmer()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Loading universe")
    }
}

#Preview {
    UniverseLoadingView()
        .preferredColorScheme(.dark)
}
