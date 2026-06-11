import SwiftUI

/// Pocket-world readout overlay — port of the web HTML readout in
/// `PocketWorldShell.tsx` (kicker "Pocket world", category shortName,
/// "N tools expanded"). Renders nothing in the core overview; appears
/// over the canvas while a pocket is open. The enter/exit transition
/// animates under the `withAnimation(BrandMotion.flow)` that drives
/// every category change in `UniverseScreen`.
struct PocketReadout: View {
    @Environment(UniverseViewModel.self) private var model

    var body: some View {
        if model.selection.activeCategory != .core {
            let category = model.selectedCategoryModel
            let toolCount = UniverseSeed.tools(in: model.selection.activeCategory).count
            VStack(spacing: 3) {
                Text("POCKET WORLD")
                    .font(.caption2.weight(.bold))
                    .tracking(1.4)
                    .foregroundStyle(category.color.swiftUIColor)
                Text(category.shortName)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                Text("\(toolCount) tools expanded")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.62))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .liquidGlass(
                in: RoundedRectangle(cornerRadius: 16, style: .continuous),
                tint: category.color.swiftUIColor,
                strokeStrength: 0.12
            )
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

#Preview {
    let model: UniverseViewModel = {
        let model = UniverseViewModel()
        model.selectCategory(.coding)
        return model
    }()
    PocketReadout()
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .environment(model)
        .preferredColorScheme(.dark)
}
