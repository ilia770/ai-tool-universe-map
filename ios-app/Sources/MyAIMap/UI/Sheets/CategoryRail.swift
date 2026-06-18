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
            LazyHStack(spacing: 6) {
                ForEach(UniverseSeed.categories) { category in
                    Button {
                        onSelect(category.id)
                    } label: {
                        let isSelected = category.id == model.selection.activeCategory
                        HStack(spacing: 6) {
                            Circle()
                                .fill(category.color.swiftUIColor)
                                .frame(width: 7, height: 7)
                                .shadow(color: category.color.swiftUIColor.opacity(isSelected ? 0.9 : 0.25), radius: isSelected ? 7 : 2)
                            Text(category.shortName)
                                .font(.system(size: 12, weight: .semibold))
                                .lineLimit(1)
                        }
                        .foregroundStyle(isSelected ? .white : .white.opacity(0.66))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .scaleEffect(isSelected ? 1.035 : 1)
                        .background(.black.opacity(isSelected ? 0.12 : 0.04), in: Capsule())
                        .liquidGlass(in: Capsule(), tint: isSelected ? category.color.swiftUIColor : nil, strokeStrength: isSelected ? 0.16 : 0.06)
                        .overlay(
                            Capsule()
                                .stroke(isSelected ? category.color.swiftUIColor.opacity(0.64) : .white.opacity(0.12), lineWidth: 1)
                        )
                        .shadow(color: category.color.swiftUIColor.opacity(isSelected ? 0.26 : 0), radius: isSelected ? 12 : 0, x: 0, y: 6)
                    }
                    .buttonStyle(PressableButtonStyle(pressedScale: 0.93, haptic: nil, pressedOpacity: 0.92))
                    .brandAnimation(BrandMotion.nudge, value: model.selection.activeCategory)
                    .id(category.id)
                }
            }
            .padding(.vertical, 8)
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollBounceBehavior(.basedOnSize)
        .scrollClipDisabled()
        .contentMargins(.horizontal, 2, for: .scrollContent)
        .frame(height: 48)
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
