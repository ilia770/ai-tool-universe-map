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
    @Environment(\.dismiss) private var dismiss
    let onOpenRelatedTool: ((String) -> Void)?
    let onClose: (() -> Void)?

    init(
        onOpenRelatedTool: ((String) -> Void)? = nil,
        onClose: (() -> Void)? = nil
    ) {
        self.onOpenRelatedTool = onOpenRelatedTool
        self.onClose = onClose
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if let onClose {
                    HStack {
                        Spacer()
                        Button {
                            onClose()
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(BrandTypography.controlLabel)
                                .foregroundStyle(.white.opacity(0.86))
                                .frame(width: 34, height: 34)
                                .glassSurface(in: Circle(), tint: .white.opacity(0.08), interactive: true)
                        }
                        .buttonStyle(.plain)
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                        .accessibilityLabel("Close detail")
                        .accessibilityIdentifier("UniverseDetail.Close")
                    }
                    .padding(.top, BrandSpacing.xl.value)
                    .padding(.trailing, BrandSpacing.xl.value)
                }

                ToolDetailSection(onOpenRelatedTool: onOpenRelatedTool)
                    .padding(.horizontal, BrandSpacing.xl.value)
                    .padding(.top, BrandSpacing.xl.value)
                    .padding(.bottom, BrandSpacing.xxl.value)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
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
                .presentationCornerRadius(BrandRadius.sheetPresentation.value)
                .environment(UniverseViewModel())
        }
        .preferredColorScheme(.dark)
}
