import SwiftUI

/// Content view for the permanent bottom sheet (Phase 2 step 7).
/// Composes `ToolDetailSection` today; future sections (relations,
/// links, clarity controls) slot into the same stack.
///
/// Background choice: `.presentationBackground` with
/// `.ultraThinMaterial` plus a faint category tint, instead of
/// `.presentationBackground(.clear)` + the `liquidGlass` card inside.
/// A clear sheet wrapping the glass card double-blurs and
/// double-strokes against the 3D canvas, and the inset card reads as
/// a floating panel inside a panel; one system material matches the
/// native drag indicator and keeps the canvas legible behind it.
struct RootSheet: View {
    @Environment(UniverseViewModel.self) private var model
    let onOpenRelatedTool: ((String) -> Void)?

    init(onOpenRelatedTool: ((String) -> Void)? = nil) {
        self.onOpenRelatedTool = onOpenRelatedTool
    }

    var body: some View {
        ScrollView {
            ToolDetailSection(onOpenRelatedTool: onOpenRelatedTool)
                .padding(.horizontal, 20)
                .padding(.top, 22)
                .padding(.bottom, 28)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .scrollClipDisabled()
        .accessibilityIdentifier("RootSheet.ToolDetail")
        .presentationBackground {
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                Rectangle().fill(.black.opacity(0.16))
                model.selectedCategoryModel.color.swiftUIColor.opacity(0.09)
            }
        }
    }
}

#Preview {
    Color.black
        .ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            RootSheet()
                .presentationDetents([.height(238), .fraction(0.48), .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(42)
                .environment(UniverseViewModel())
        }
        .preferredColorScheme(.dark)
}
