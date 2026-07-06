import SwiftUI

/// Horizontal category chip rail. Extracted verbatim from
/// `UniverseScreen` (Phase 2 step 7) — same visuals and behavior.
/// Reads selection state from the environment model; the selection
/// action (and its haptic logic) stays with the owner via `onSelect`
/// so chip taps and proximity enter/exit share one code path.
struct CategoryRail: View {
    @Environment(UniverseViewModel.self) private var model

    let onSelect: (ToolCategoryId) -> Void

    /// Only categories that currently have at least one visible tool, so a
    /// sparse (empty-start) universe never shows chips that dead-end on tap.
    private var presentCategories: [ToolCategory] {
        UniverseSeed.categories.filter { category in
            model.visibleAllTools.contains { $0.category == category.id }
        }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            // Neighbouring glass chips share one container so the system merges
            // their lensing instead of stacking individual glass layers.
            chipRow
                .modifier(CategoryChipContainer())
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollBounceBehavior(.basedOnSize)
        .scrollClipDisabled()
        .contentMargins(.horizontal, 2, for: .scrollContent)
        .frame(height: 48)
    }

    private var chipRow: some View {
        LazyHStack(spacing: BrandSpacing.s.value) {
                ForEach(presentCategories) { category in
                    Button {
                        onSelect(category.id)
                    } label: {
                        let isSelected = category.id == model.selection.activeCategory
                        HStack(spacing: BrandSpacing.s.value) {
                            Circle()
                                .fill(category.color.swiftUIColor)
                                .frame(width: 7, height: 7)
                                .shadow(color: category.color.swiftUIColor.opacity(isSelected ? 0.9 : 0.25), radius: isSelected ? 7 : 2)
                            Text(category.shortName)
                                .font(BrandTypography.chip)
                                .lineLimit(1)
                        }
                        .foregroundStyle(isSelected ? .white : .white.opacity(0.66))
                        .padding(.horizontal, BrandSpacing.sm.value)
                        .padding(.vertical, BrandSpacing.s.value)
                        .scaleEffect(isSelected ? 1.035 : 1)
                        .background(.black.opacity(isSelected ? 0.12 : 0.04), in: Capsule())
                        .glassSurface(in: Capsule(), tint: isSelected ? category.color.swiftUIColor : nil, interactive: true)
                        .overlay(
                            Capsule()
                                .stroke(isSelected ? category.color.swiftUIColor.opacity(0.64) : .white.opacity(0.12), lineWidth: 1)
                        )
                        .shadow(color: category.color.swiftUIColor.opacity(isSelected ? 0.26 : 0), radius: isSelected ? 12 : 0, x: 0, y: 6)
                        // Keep the visual capsule compact but guarantee a 44pt
                        // tap target (Apple HIG minimum) around it.
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PressableButtonStyle(pressedScale: 0.93, haptic: nil, pressedOpacity: 0.92))
                    .brandAnimation(BrandMotion.nudge, value: model.selection.activeCategory)
                    .id(category.id)
                }
        }
        .padding(.vertical, BrandSpacing.s.value)
        .scrollTargetLayout()
    }
}

/// Wraps the chip row in a `GlassEffectContainer` on iOS 26 so adjacent glass
/// capsules merge their lensing; older OSes render the row unchanged.
private struct CategoryChipContainer: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer { content }
        } else {
            content
        }
    }
}

#Preview {
    CategoryRail { _ in }
        .padding(.horizontal, BrandSpacing.l.value)
        .frame(maxWidth: .infinity)
        .background(Color.black)
        .environment(UniverseViewModel())
        .preferredColorScheme(.dark)
}
