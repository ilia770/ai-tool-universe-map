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

    var body: some View {
        ScrollView {
            ToolDetailSection()
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .presentationBackground {
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                model.selectedCategoryModel.color.swiftUIColor.opacity(0.07)
            }
        }
    }
}

#Preview {
    Color.black
        .ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            RootSheet()
                .presentationDetents([.height(118), .fraction(0.42), .large])
                .presentationDragIndicator(.visible)
                .environment(UniverseViewModel())
        }
        .preferredColorScheme(.dark)
}
