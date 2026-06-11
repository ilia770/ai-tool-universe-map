import SwiftUI

/// Compact segmented glass control for the map clarity mode, mirroring
/// the web F / C / A hotkeys (`mapClarity: 'focus' | 'context' | 'atlas'`
/// in AIToolUniverseMap.tsx). Labels are the mode raw values, matching
/// web naming; the web build has no on-screen labels (hotkeys only).
/// Selected segment gets the active category tint + stronger stroke,
/// per `CategoryRail`'s selected-chip precedent.
struct ClarityMenu: View {
    @Environment(UniverseViewModel.self) private var model

    var body: some View {
        HStack(spacing: 4) {
            ForEach(ClarityMode.allCases, id: \.self) { mode in
                segment(mode)
            }
        }
        .padding(4)
        .liquidGlass(in: Capsule(), strokeStrength: 0.08)
    }

    @ViewBuilder
    private func segment(_ mode: ClarityMode) -> some View {
        let isSelected = mode == model.clarityMode
        let tint = model.selectedCategoryModel.color.swiftUIColor
        Button {
            BrandHaptics.fire(.light)
            guard model.clarityMode != mode else { return }
            withAnimation(BrandMotion.nudge) {
                model.clarityMode = mode
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: symbol(for: mode))
                    .font(.system(size: 11, weight: .semibold))
                Text(mode.rawValue.capitalized)
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(isSelected ? .white : .white.opacity(0.62))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background {
                if isSelected {
                    Capsule().fill(tint.opacity(0.22))
                }
            }
            .overlay(
                Capsule()
                    .stroke(isSelected ? tint.opacity(0.64) : .clear, lineWidth: 1)
            )
        }
        .buttonStyle(PressableButtonStyle(pressedScale: 0.93, haptic: nil, pressedOpacity: 0.92))
        .brandAnimation(BrandMotion.nudge, value: model.clarityMode)
    }

    private func symbol(for mode: ClarityMode) -> String {
        switch mode {
        case .focus: "scope"
        case .context: "circle.hexagongrid"
        case .atlas: "square.grid.3x3"
        }
    }
}

#Preview {
    ClarityMenu()
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Color.black)
        .environment(UniverseViewModel())
        .preferredColorScheme(.dark)
}
