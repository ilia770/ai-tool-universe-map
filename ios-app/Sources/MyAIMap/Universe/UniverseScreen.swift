import SwiftUI

struct UniverseScreen: View {
    @Environment(UniverseViewModel.self) private var model
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var sheetPresented = false
    @State private var sheetDetent: PresentationDetent = .height(118)

    private var selectedCategoryModel: ToolCategory {
        model.selectedCategoryModel
    }

    private var selectedTool: Tool {
        model.selectedTool
    }

    var body: some View {
        Group {
            if AdaptiveLayout.isCompact(horizontalSizeClass) {
                // iPhone: the tool detail lives in a permanent bottom sheet
                // that sits over the canvas chrome. Unchanged from launch.
                canvas
                    .sheet(isPresented: $sheetPresented) {
                        RootSheet()
                            .presentationDetents([.height(118), .fraction(0.42), .large], selection: $sheetDetent)
                            .presentationBackgroundInteraction(.enabled(upThrough: .fraction(0.42)))
                            .presentationDragIndicator(.visible)
                            .interactiveDismissDisabled(true)
                            .onChange(of: sheetDetent) { _, _ in
                                // Settling on a detent is a positional commit, like a
                                // picker tick — lighter than category/pocket events.
                                BrandHaptics.fire(.light)
                            }
                    }
            } else {
                // iPad / regular width: a blocking sheet would cover the map,
                // so the detail becomes an always-visible trailing panel and
                // the canvas keeps the remaining width fully interactive.
                HStack(spacing: 0) {
                    canvas
                        .frame(maxWidth: .infinity)
                    RootSheet()
                        .frame(width: 360)
                        // `.presentationBackground` is a no-op outside a sheet,
                        // so reapply the same material + tint here to keep the
                        // panel's glass consistent with the iPhone sheet.
                        .background {
                            ZStack {
                                Rectangle().fill(.ultraThinMaterial)
                                selectedCategoryModel.color.swiftUIColor.opacity(0.07)
                            }
                            .ignoresSafeArea()
                        }
                }
            }
        }
        .background(Color.black)
        .preferredColorScheme(.dark)
        .onAppear {
            sheetPresented = true
            BrandHaptics.prepare(.light, .medium, .heavy, .success)
        }
    }

    private var canvas: some View {
        ZStack {
            UniverseView(
                selectedCategory: model.selection.activeCategory,
                selectedToolId: selectedTool.id,
                onToolSelect: { toolId in
                    focusToolFromMap(toolId)
                },
                onProximityEvent: { event in
                    // Web parity (Scene.tsx:420-421): onEnter selects the
                    // category, onExit returns to the overview ('all' ↔ .core).
                    switch event {
                    case .enter(let id):
                        selectCategory(id)
                    case .exit:
                        selectCategory(.core)
                    }
                }
            )
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                SearchDock()
                    .padding(.top, 10)
                PocketReadout()
                    .padding(.top, 12)
                Spacer(minLength: 0)
                ClarityMenu()
                    .frame(maxWidth: .infinity, alignment: .trailing)
                CategoryRail { id in
                    selectCategory(id)
                }
                // Keep the rail visible above the sheet's compact detent.
                .padding(.bottom, 118)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(selectedCategoryModel.color.swiftUIColor)
                .frame(width: 42, height: 42)
                .liquidGlass(
                    in: RoundedRectangle(cornerRadius: 13, style: .continuous),
                    tint: selectedCategoryModel.color.swiftUIColor,
                    strokeStrength: 0.16
                )

            VStack(alignment: .leading, spacing: 3) {
                Text("My AI Map")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                Text("Research -> Plan -> Build -> Review")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.62))
            }

            Spacer()

            Text("\(UniverseSeed.tools.count) tools")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.72))
                .padding(.horizontal, 11)
                .padding(.vertical, 8)
                .liquidGlass(in: Capsule(), tint: selectedCategoryModel.color.swiftUIColor.opacity(0.5), strokeStrength: 0.08)
        }
        .brandAnimation(BrandMotion.flow, value: model.selection.activeCategory)
    }

    private func selectCategory(_ id: ToolCategoryId) {
        let previous = model.selection.activeCategory
        if previous == id {
            BrandHaptics.fire(.light)
            return
        }

        if id == .core {
            BrandHaptics.fireRich(.pocketClose)
        } else if previous == .core {
            BrandHaptics.fireRich(.pocketOpen)
        } else {
            BrandHaptics.fire(.medium)
        }

        withAnimation(BrandMotion.flow) {
            model.selectCategory(id)
        }
    }

    private func focusToolFromMap(_ id: String) {
        guard model.selection.selectedToolID != id else {
            BrandHaptics.fire(.light)
            return
        }
        BrandHaptics.fire(.medium)
        withAnimation(BrandMotion.flow) {
            _ = model.focusTool(id)
        }
    }
}

#Preview {
    UniverseScreen()
        .environment(UniverseViewModel())
}
