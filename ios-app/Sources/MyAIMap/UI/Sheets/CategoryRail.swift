import SwiftUI

/// Horizontal category chip rail. Extracted verbatim from
/// `UniverseScreen` (Phase 2 step 7) — same visuals and behavior.
/// Reads selection state from the environment model; the selection
/// action (and its haptic logic) stays with the owner via `onSelect`
/// so chip taps and proximity enter/exit share one code path.
struct CategoryRail: View {
    @Environment(UniverseViewModel.self) private var model

    let onSelect: (ToolCategoryId) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(UniverseSeed.categories) { category in
                    Button {
                        onSelect(category.id)
                    } label: {
                        let isSelected = category.id == model.selection.activeCategory
                        HStack(spacing: 7) {
                            Circle()
                                .fill(category.color.swiftUIColor)
                                .frame(width: 8, height: 8)
                                .shadow(color: category.color.swiftUIColor.opacity(isSelected ? 0.9 : 0.25), radius: isSelected ? 7 : 2)
                            Text(category.shortName)
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(isSelected ? .white : .white.opacity(0.66))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .scaleEffect(isSelected ? 1.035 : 1)
                        .liquidGlass(in: Capsule(), tint: isSelected ? category.color.swiftUIColor : nil, strokeStrength: isSelected ? 0.16 : 0.06)
                        .overlay(
                            Capsule()
                                .stroke(isSelected ? category.color.swiftUIColor.opacity(0.64) : .white.opacity(0.12), lineWidth: 1)
                        )
                    }
                    .buttonStyle(PressableButtonStyle(pressedScale: 0.93, haptic: nil, pressedOpacity: 0.92))
                    .brandAnimation(BrandMotion.nudge, value: model.selection.activeCategory)
                }
            }
            .padding(.vertical, 10)
        }
    }
}

#Preview {
    CategoryRail { _ in }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .background(Color.black)
        .environment(UniverseViewModel())
        .preferredColorScheme(.dark)
}
