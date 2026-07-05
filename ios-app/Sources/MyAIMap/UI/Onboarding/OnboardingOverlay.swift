import SwiftUI

/// The three first-run actions, in the order they appear (top → bottom).
/// Pulled out as a value type so the routing is unit-testable and the overlay
/// stays declarative.
enum OnboardingAction: String, CaseIterable, Identifiable {
    case askAI
    case addTool
    case exploreMap

    var id: String { rawValue }

    var title: String {
        switch self {
        case .askAI: "Ask AI"
        case .addTool: "Add Tool"
        case .exploreMap: "Explore Map"
        }
    }

    var systemImage: String {
        switch self {
        case .askAI: "text.bubble.fill"
        case .addTool: "plus"
        case .exploreMap: "map.fill"
        }
    }

    var accessibilityIdentifier: String {
        switch self {
        case .askAI: "Onboarding.AskAI"
        case .addTool: "Onboarding.AddTool"
        case .exploreMap: "Onboarding.ExploreMap"
        }
    }

    /// `.askAI` reads as the primary call-to-action; the rest are quieter glass.
    var isPrimary: Bool { self == .askAI }
}

/// Lightweight one-screen first-run onboarding, layered over the (empty) map.
///
/// One screen, no paging. It explains the product in a single line and offers
/// the three obvious next steps. Any action — plus the Skip control and a scrim
/// tap — dismisses it and routes via `onAction`; the caller persists the
/// first-run flag so it never shows again. Liquid Glass styling, reduce-motion
/// safe (the scrim and card fade in only when motion is allowed).
struct OnboardingOverlay: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Routes a chosen action. `nil` means dismiss-only (Skip / scrim tap),
    /// which behaves like Explore Map per the spec.
    let onAction: (OnboardingAction?) -> Void

    @State private var appeared = false

    var body: some View {
        ZStack {
            // Scrim: dims the map behind and dismisses (→ Explore Map) on tap.
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { onAction(nil) }
                .accessibilityIdentifier("Onboarding.Scrim")
                .accessibilityLabel("Dismiss onboarding")
                .accessibilityAddTraits(.isButton)

            card
                .padding(.horizontal, 28)
                .frame(maxWidth: 420)
                .scaleEffect(appeared || reduceMotion ? 1 : 0.96)
                .opacity(appeared || reduceMotion ? 1 : 0)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withBrandAnimation(BrandMotion.reveal, reduceMotion: reduceMotion) {
                appeared = true
            }
        }
    }

    private var card: some View {
        VStack(spacing: 22) {
            VStack(spacing: 12) {
                ZStack {
                    Circle().fill(BrandColor.core.opacity(0.16))
                    Image(systemName: "sparkles")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(BrandColor.core)
                }
                .frame(width: 60, height: 60)
                .accessibilityHidden(true)

                Text("AI Universe")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .accessibilityAddTraits(.isHeader)

                Text("Map your tools into branches. Add tools, ask AI, and explore your stack.")
                    .font(.subheadline)
                    .lineSpacing(3)
                    .foregroundStyle(.white.opacity(0.72))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Skip belongs to the same cluster as the action buttons so it
            // reads as the quiet tertiary option *below* them — a tighter,
            // deliberate gap rather than the 22pt section break that made it
            // look like a detached, free-floating control.
            VStack(spacing: 14) {
                VStack(spacing: 10) {
                    ForEach(OnboardingAction.allCases) { action in
                        actionButton(action)
                    }
                }

                Button {
                    onAction(nil)
                } label: {
                    Text("Skip")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
                .hitArea()
                .accessibilityIdentifier("Onboarding.Skip")
            }
        }
        .padding(.vertical, 30)
        .padding(.horizontal, 26)
        .glassSurface(in: RoundedRectangle(cornerRadius: 30, style: .continuous), tint: BrandColor.core.opacity(0.10))
    }

    @ViewBuilder
    private func actionButton(_ action: OnboardingAction) -> some View {
        Button {
            onAction(action)
        } label: {
            HStack(spacing: 9) {
                Image(systemName: action.systemImage)
                    .font(.system(size: 14, weight: .bold))
                Text(action.title)
                    .font(BrandTypography.controlLabel)
            }
            .frame(maxWidth: .infinity, minHeight: 30)
            .padding(.vertical, 11)
            .padding(.horizontal, BrandSpacing.l.value)
            .foregroundStyle(action.isPrimary ? .black : .white)
            .modifier(OnboardingButtonSurface(isPrimary: action.isPrimary))
        }
        .buttonStyle(PressableButtonStyle(pressedScale: 0.97, haptic: .light))
        .hitArea()
        .accessibilityIdentifier(action.accessibilityIdentifier)
    }
}

/// Primary action reads as a solid, high-contrast capsule (the core CTA);
/// secondary actions use quiet Liquid Glass per the HIG control-layer contract.
private struct OnboardingButtonSurface: ViewModifier {
    let isPrimary: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if isPrimary {
            content.background(BrandColor.core, in: Capsule())
        } else {
            content.glassSurface(in: Capsule(), tint: BrandColor.core.opacity(0.16))
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        OnboardingOverlay { _ in }
    }
}
