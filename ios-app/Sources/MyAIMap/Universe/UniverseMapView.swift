import SwiftUI
import UIKit

/// Production-style 2D-first universe map: SwiftUI constellation + glass UI.
struct UniverseMapView: View {
    @Environment(UniverseViewModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @State private var accountPresented = false
    @State private var addToolPresented = false
    /// §2 morph: zoom-transition source namespace shared between the chrome
    /// trigger buttons (in `UniverseOverlayView`) and the sheets presented here,
    /// so Plus→Add Tool and Profile→Settings feel like one continuous surface.
    @Namespace private var chromeMorphNamespace
    @State private var addToolDraft: MissingToolSuggestion?

    @State private var planets: [PlanetData] = []

    /// Read alias for the single source of truth. All writes go to
    /// `model.universeMode`; the view never stores a second copy of the mode
    /// (see docs/UI_STATE_MACHINE.md).
    private var mode: UniverseMode { model.universeMode }

    /// iPhone (or iPad slide-over) uses the bottom-sheet detail; regular width
    /// (iPad) uses an always-visible trailing inspector panel instead.
    private var isCompact: Bool { AdaptiveLayout.isCompact(hSizeClass) }

    /// The sole compact-detail sheet binding. SwiftUI writes `nil` when a
    /// system dismissal completes; both that write and `onDismiss` delegate to
    /// the model so the captured route decides the restoration state.
    private var detailRouteBinding: Binding<DetailRoute?> {
        Binding(
            get: { isCompact ? model.detailRoute : nil },
            set: { route in
                guard route == nil else { return }
                model.dismissDetail()
            }
        )
    }

    private func rebuildPlanets() {
        // Feed seed branches AND user/AI-created custom branches; makePlanets
        // only emits planets for categories that hold a visible tool.
        planets = PlanetData.makePlanets(categories: model.allCategories, tools: model.visibleAllTools)
    }

    private var selectedPlanet: PlanetData {
        planets.first { $0.id == mode.focusedCategory }
            ?? planets.first { $0.id == .core }
            ?? PlanetData.core(from: model.visibleAllTools)
    }

    private var selectedTool: Tool {
        if let selectedToolID = mode.selectedToolID,
           let tool = model.visibleAllTools.first(where: { $0.id == selectedToolID }) {
            return tool
        }
        // Defensive fallback: detail/tool UI is only reachable once a real tool
        // is selected, so `model.selectedTool` is non-nil there. The empty
        // universe never opens these surfaces (gated by the empty state).
        return model.selectedTool ?? UniverseSeed.tools[0]
    }

    private var universeStack: some View {
        ZStack {
            releaseMapRenderer

            Color.black
                .opacity(mode.dimOpacity)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            UniverseOverlayView(
                planets: planets,
                mode: mode,
                selectedPlanet: selectedPlanet,
                selectedTool: selectedTool,
                onCategorySelect: selectCategory,
                onToolSelect: focusToolFromMap,
                onOpenToolDetail: openToolDetailFromChat,
                onChatActivityChange: setChatOpen,
                onDetails: presentDetail,
                onAccount: presentAccount,
                onAddTool: { presentAddTool() },
                chromeMorphNamespace: chromeMorphNamespace,
                onAddSuggestedTool: { suggestion in presentAddTool(draft: suggestion) }
            )
        }
    }

    @ViewBuilder
    private var releaseMapRenderer: some View {
        switch MapRendererKind.release {
        case .constellation2D:
            UniverseConstellationView(
                planets: planets,
                mode: mode,
                onPlanetTap: selectCategory,
                onToolTap: focusToolFromMap,
                onEmptyTap: handleEmptySpaceTap
            )
            .ignoresSafeArea()
        }
    }

    /// iPad trailing inspector: the selected tool's detail as a persistent
    /// side panel (a blocking sheet would cover the map). Shown only when a
    /// tool is selected in a non-empty universe.
    @ViewBuilder
    private var inspectorPanel: some View {
        if !model.isUniverseEmpty, mode.selectedToolID != nil {
            RootSheet(onOpenRelatedTool: openRelatedToolFromDetail)
                .frame(width: 360)
                .background {
                    ZStack {
                        Rectangle().fill(.ultraThinMaterial)
                        selectedPlanet.swiftUIColor.opacity(0.07)
                    }
                    .ignoresSafeArea()
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
        }
    }

    var body: some View {
        Group {
            if isCompact {
                universeStack
            } else {
                HStack(spacing: 0) {
                    universeStack
                        .frame(maxWidth: .infinity)
                    inspectorPanel
                }
                .brandAnimation(BrandMotion.flow, value: model.selection.selectedToolID)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BrandColor.void)
        .preferredColorScheme(.dark)
        .onAppear {
            if planets.isEmpty {
                rebuildPlanets()
            }
            BrandHaptics.isEnabled = model.hapticsEnabled
            BrandHaptics.prepare(.light, .medium, .heavy, .success)
            reconcileDetailRouteForLayout()
        }
        .onChange(of: model.hapticsEnabled) { _, isEnabled in
            BrandHaptics.isEnabled = isEnabled
        }
        .onChange(of: isCompact) { _, _ in reconcileDetailRouteForLayout() }
        .sheet(item: detailRouteBinding, onDismiss: { model.dismissDetail() }) { _ in
            compactDetailSheet
        }
        .sheet(isPresented: $accountPresented) {
            AccountSettingsSheet()
                .environment(model)
                .liquidGlassSheet()
                .navigationTransition(.zoom(sourceID: ChromeMorphID.account, in: chromeMorphNamespace))
        }
        .sheet(isPresented: $addToolPresented) {
            AddToolSheet(draft: addToolDraft)
                .environment(model)
                .liquidGlassSheet()
                .navigationTransition(.zoom(sourceID: ChromeMorphID.addTool, in: chromeMorphNamespace))
        }
        .onChange(of: addToolPresented) { _, isPresented in
            if !isPresented {
                addToolDraft = nil
            }
        }
        .onChange(of: model.visibleAllTools.map(\.id)) { _, _ in
            rebuildPlanets()
        }
    }

    private func selectCategory(_ id: ToolCategoryId) {
        let previous = mode.focusedCategory
        if previous == id, !mode.isChatOpen, !mode.isDetailOpen {
            if mode.selectedToolID != nil {
                presentDetail()
            } else if id == .core {
                resetToOverview()
            }
            return
        }

        if id == .core {
            BrandHaptics.fireRich(.pocketClose)
        } else if previous == .core {
            BrandHaptics.fireRich(.pocketOpen)
        } else {
            BrandHaptics.fire(.medium)
        }

        withBrandAnimation(BrandMotion.flow, reduceMotion: reduceMotion) {
            model.selectCategory(id)
        }
    }

    private func focusToolFromMap(_ id: String) {
        guard model.visibleAllTools.contains(where: { $0.id == id }) else { return }
        guard mode.selectedToolID != id else {
            presentDetail()
            return
        }
        BrandHaptics.fire(.medium)
        withBrandAnimation(BrandMotion.flow, reduceMotion: reduceMotion) {
            _ = model.focusTool(id)
        }
    }

    private func openToolDetailFromChat(_ id: String) {
        if isCompact {
            model.requestDetail(for: id)
        } else {
            _ = model.focusTool(id)
        }
    }

    private func openRelatedToolFromDetail(_ id: String) {
        if isCompact {
            model.replaceDetailTool(with: id)
        } else {
            _ = model.focusTool(id)
        }
    }

    private func resetToOverview() {
        dismissKeyboard()
        guard mode != .overview else { return }
        BrandHaptics.fireRich(.pocketClose)
        withBrandAnimation(BrandMotion.flow, reduceMotion: reduceMotion) {
            model.selectCategory(.core)
        }
    }

    private func handleEmptySpaceTap() {
        dismissKeyboard()
        if mode.isChatOpen {
            restoreNavigationMode(animated: true)
        } else if mode.isDetailOpen {
            return
        } else if mode != .overview {
            BrandHaptics.fire(.light)
            withAnimation(BrandMotion.flow) { model.universeMode = mode.steppedBack }
        } else {
            resetToOverview()
        }
    }

    private func presentDetail() {
        BrandHaptics.fire(.medium)
        // iPad: the trailing inspector panel already shows the selected tool's
        // detail, and entering .detail mode would dim the map behind it. Keep
        // the current (toolSelected) mode; the panel is the detail surface.
        guard isCompact else { return }
        model.requestDetail(for: selectedTool.id)
    }

    private func setChatOpen(_ isOpen: Bool) {
        if isOpen {
            guard model.detailRoute == nil else { return }
            model.universeMode = .chatContext(
                activeCategory: model.selection.activeCategory,
                projectedSelectedToolID: model.selection.selectedToolID,
                explicitSelectedToolID: mode.selectedToolID
            )
        } else if mode.isChatOpen {
            restoreNavigationMode(animated: true)
        }
    }

    private func restoreNavigationMode(animated: Bool) {
        if case .chatOpen(let category, let toolID) = mode,
           let category,
           let toolID,
           model.visibleAllTools.contains(where: { $0.id == toolID && $0.category == category }) {
            model.universeMode = .toolSelected(category, toolID)
            return
        }
        model.universeMode = navigationModeForSelection()
    }

    private func navigationModeForSelection() -> UniverseMode {
        let category = model.selection.activeCategory
        guard category != .core else { return .overview }
        return .branchFocus(category)
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private var compactDetailSheet: some View {
        RootSheet(onOpenRelatedTool: openRelatedToolFromDetail)
            .overlay(alignment: .topTrailing) {
                DetailCloseControl(model: model)
            }
            .presentationDetents([.fraction(0.72), .large])
            .presentationBackgroundInteraction(.enabled(upThrough: .fraction(0.72)))
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(42)
    }

    /// A regular-width inspector is selection-derived rather than a compact
    /// sheet. Restoring a route there keeps its existing map presentation.
    private func reconcileDetailRouteForLayout() {
        guard !isCompact, model.detailRoute != nil else { return }
        model.dismissDetail()
    }

    private func presentAccount() {
        BrandHaptics.fire(.medium)
        if model.detailRoute != nil {
            model.dismissDetail()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                accountPresented = true
            }
        } else {
            accountPresented = true
        }
    }

    private func presentAddTool() {
        presentAddTool(draft: nil)
    }

    private func presentAddTool(draft: MissingToolSuggestion?) {
        BrandHaptics.fire(.medium)
        addToolDraft = draft
        if model.detailRoute != nil {
            model.dismissDetail()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                addToolPresented = true
            }
        } else {
            addToolPresented = true
        }
    }

    /// A sheet-local dismissal closes the currently presented system sheet
    /// immediately, while the model remains the authority for route cleanup.
    private struct DetailCloseControl: View {
        let model: UniverseViewModel
        @Environment(\.dismiss) private var dismiss

        var body: some View {
            Button {
                model.dismissDetail()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(BrandTypography.controlLabel)
                    .foregroundStyle(.white.opacity(0.86))
                    .frame(width: 34, height: 34)
                    .glassSurface(in: Circle(), tint: .white.opacity(0.08), interactive: true)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close detail")
            .accessibilityIdentifier("UniverseDetail.Close")
            .padding(.top, BrandSpacing.xl.value)
            .padding(.trailing, BrandSpacing.xl.value)
        }
    }
}

#Preview {
    UniverseMapView()
        .environment(UniverseViewModel())
}
