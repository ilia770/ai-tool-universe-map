import SwiftUI

/// A horizontal cluster of options whose *selected* option is a single
/// travelling Liquid Glass shape: one glass element morphs place/shape/size
/// between slots instead of separate elements appearing/disappearing. The
/// canonical pattern for tab bars, segmented controls, and mode toggles.
///
/// Tiering lives in `glassSurface` / `navigationGlassMorphID`: iOS 26 native
/// `glassEffect` + `glassEffectID`; iOS 18–25 `matchedGeometryEffect`; Reduce
/// Transparency opaque. Container spacing equals the HStack spacing per HIG.
struct GlassMorphCluster<Option: Identifiable, Label: View>: View {
    let options: [Option]
    @Binding var selection: Int
    let base: String
    var spacing: CGFloat = BrandSpacing.xs.value
    var tint: Color? = nil
    @ViewBuilder let label: (Option, Bool) -> Label

    @Namespace private var ns
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var selectedIndex: Int {
        GlassMorphSelection.clamped(selection, count: options.count)
    }

    var body: some View {
        container {
            HStack(spacing: spacing) {
                ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                    let isSelected = index == selectedIndex
                    Button {
                        withBrandAnimation(BrandMotion.morph, reduceMotion: reduceMotion) {
                            selection = index
                        }
                    } label: {
                        label(option, isSelected)
                            .font(BrandTypography.controlLabel)
                            .padding(.horizontal, BrandSpacing.m.value)
                            .padding(.vertical, BrandSpacing.s.value)
                    }
                    .buttonStyle(PressableButtonStyle(pressedScale: 0.96, haptic: .light))
                    .glassSurface(tint: isSelected ? (tint ?? .white.opacity(0.10)) : nil, interactive: true)
                    .navigationGlassMorphID(
                        GlassMorphSelection.glassID(optionIndex: index, selectedIndex: selectedIndex, base: base),
                        in: ns
                    )
                    .hitArea()
                    .accessibilityIdentifier("\(base).\(index)")
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(spacing)
        }
    }

    @ViewBuilder
    private func container<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) { content() }
        } else {
            content()
        }
    }
}
