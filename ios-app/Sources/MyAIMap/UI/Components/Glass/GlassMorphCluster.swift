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
    var spacing: CGFloat = BrandSpacing.s.value
    var tint: Color? = nil
    /// Per-option accessibility identifier. Defaults to `"<base>.<index>"`;
    /// override to preserve pre-existing identifiers (e.g. a migrated control
    /// whose ids are already asserted by UI tests).
    var identifier: (Int) -> String = { _ in "" }
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
                        optionLabel(option, isSelected: isSelected)
                    }
                    .buttonStyle(GlassControlButtonStyle(
                        haptic: .light,
                        ownsInteractiveGlass: isSelected
                    ))
                    .hitArea()
                    .accessibilityIdentifier({ let id = identifier(index); return id.isEmpty ? "\(base).\(index)" : id }())
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(BrandSpacing.xs.value)
        }
    }

    @ViewBuilder
    private func optionLabel(_ option: Option, isSelected: Bool) -> some View {
        let content = label(option, isSelected)
            .font(BrandTypography.controlLabel)
            .lineLimit(1)
            .minimumScaleFactor(0.88)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, BrandSpacing.m.value)
            .padding(.vertical, BrandSpacing.s.value)
            .frame(minHeight: HitArea.minimum)

        if isSelected {
            content
                .glassSurface(tint: tint ?? .white.opacity(0.10), interactive: true)
                .navigationGlassMorphID("\(base).active", in: ns)
        } else {
            content
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
