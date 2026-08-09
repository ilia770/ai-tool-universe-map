import SwiftUI
import UIKit

/// Production-style 2D-first universe map: SwiftUI constellation + glass UI.
struct UniverseMapView: View {
    @Environment(UniverseViewModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @State private var sceneController = UniverseSceneController()
    @State private var cameraRig = CameraRigController()
    @State private var gestureController = UniverseGestureController()
    @State private var modeBeforeDetail: UniverseMode?
    @State private var detailPresented = false
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
            UniverseConstellationView(
                planets: planets,
                mode: mode,
                onPlanetTap: selectCategory,
                onToolTap: focusToolFromMap,
                onEmptyTap: handleEmptySpaceTap
            )
            .ignoresSafeArea()

            Color.black
                .opacity(mode.dimOpacity)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            UniverseOverlayView(
                planets: planets,
                mode: mode,
                cameraRig: cameraRig,
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
                onAddSuggestedTool: { suggestion in presentAddTool(draft: suggestion) },
                showsProjectedMapLabels: false
            )
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
                .background(BrandColor.glass)
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
            focusCamera(for: mode, animated: false)
            // A chat "open detail" chip sets the request before this surface
            // mounts, so consume it here (onChange alone would miss it).
            consumePendingDetailRequest()
        }
        .onChange(of: model.pendingDetailToolID) { _, _ in
            consumePendingDetailRequest()
        }
        .onChange(of: model.hapticsEnabled) { _, isEnabled in
            BrandHaptics.isEnabled = isEnabled
        }
        .onChange(of: model.universeMode) { _, newMode in
            focusCamera(for: newMode, animated: true)
            // Single source of truth: the model owns whether detail is open.
            // If the model leaves `.detail` for any reason (e.g. deleting the
            // selected tool from the sheet), dismiss the local sheet so it
            // cannot outlive the navigation state.
            if !newMode.isDetailOpen, detailPresented {
                detailPresented = false
            }
        }
        .onChange(of: detailPresented) { _, isPresented in
            if isPresented {
                model.universeMode = .detail(selectedTool.category, selectedTool.id)
            } else if mode.isDetailOpen {
                model.universeMode = modeBeforeDetail ?? navigationModeForSelection()
                modeBeforeDetail = nil
            }
        }
        .sheet(isPresented: $detailPresented) {
            RootSheet(onOpenRelatedTool: openRelatedToolFromDetail)
                .presentationDetents([.fraction(0.72), .large])
                .presentationBackgroundInteraction(.enabled(upThrough: .fraction(0.72)))
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(42)
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
            focusCamera(for: mode, animated: false)
        }
    }

    private func selectCategory(_ id: ToolCategoryId) {
        let previous = mode.focusedCategory
        if previous == id, !mode.isChatOpen, !mode.isDetailOpen {
            if mode.selectedToolID != nil {
                presentDetail()
            } else if id == .core {
                resetToOverview()
            } else if let planet = planets.first(where: { $0.id == id }) {
                BrandHaptics.fire(.light)
                cameraRig.focus(on: planet, animated: true)
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
        guard let tool = model.visibleAllTools.first(where: { $0.id == id }) else { return }
        if isCompact {
            modeBeforeDetail = .toolSelected(tool.category, tool.id)
            model.universeMode = .detail(tool.category, tool.id)
            detailPresented = true
        } else {
            model.universeMode = .toolSelected(tool.category, tool.id)
        }
    }

    private func openRelatedToolFromDetail(_ id: String) {
        guard let tool = model.visibleAllTools.first(where: { $0.id == id }) else { return }
        if isCompact {
            modeBeforeDetail = .toolSelected(tool.category, tool.id)
            model.universeMode = .detail(tool.category, tool.id)
        } else {
            model.universeMode = .toolSelected(tool.category, tool.id)
        }
    }

    private func resetToOverview() {
        dismissKeyboard()
        guard mode != .overview else {
            cameraRig.overview(animated: true)
            return
        }
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

    private func focusCamera(for mode: UniverseMode, animated: Bool) {
        if case .chatOpen(let category, _) = mode {
            let planet = category.flatMap { id in planets.first { $0.id == id } }
            cameraRig.enterChat(focusedOn: planet, animated: animated)
            return
        }

        if let toolID = mode.selectedToolID,
           mode.focusedCategory == .core {
            let core = planets.first(where: { $0.id == .core }) ?? PlanetData.core(from: model.visibleAllTools)
            guard toolID != PlanetData.centralCoreToolID,
                  let toolIndex = core.tools.firstIndex(where: { $0.id == toolID }) else {
                cameraRig.focus(category: core, animated: animated)
                return
            }
            cameraRig.focus(
                tool: core.tools[toolIndex],
                around: core,
                index: toolIndex,
                count: core.tools.count,
                animated: animated
            )
            return
        }

        guard mode.focusedCategory != .core,
              let planet = planets.first(where: { $0.id == mode.focusedCategory }) else {
            cameraRig.returnToOverview(animated: animated)
            return
        }

        if let toolID = mode.selectedToolID,
           let toolIndex = planet.tools.firstIndex(where: { $0.id == toolID }) {
            if mode.isDetailOpen {
                cameraRig.enterDetail(
                    tool: planet.tools[toolIndex],
                    around: planet,
                    index: toolIndex,
                    count: planet.tools.count,
                    animated: animated
                )
            } else {
                cameraRig.focus(
                    tool: planet.tools[toolIndex],
                    around: planet,
                    index: toolIndex,
                    count: planet.tools.count,
                    animated: animated
                )
            }
            return
        }
        cameraRig.focus(category: planet, animated: animated)
    }

    /// Presents the detail for a tool requested from the chat surface (§6.3).
    /// Selection was already set by `requestToolDetail`; this just opens the
    /// sheet (or, on iPad, the inspector already shows it via the selection).
    private func consumePendingDetailRequest() {
        guard let id = model.pendingDetailToolID else { return }
        model.pendingDetailToolID = nil
        guard model.visibleAllTools.contains(where: { $0.id == id }) else { return }
        if mode.selectedToolID != id {
            _ = model.focusTool(id)
        }
        presentDetail()
    }

    private func presentDetail() {
        BrandHaptics.fire(.medium)
        // iPad: the trailing inspector panel already shows the selected tool's
        // detail, and entering .detail mode would dim the map behind it. Keep
        // the current (toolSelected) mode; the panel is the detail surface.
        guard isCompact else { return }
        if !mode.isDetailOpen {
            modeBeforeDetail = mode
        }
        model.universeMode = .detail(selectedTool.category, selectedTool.id)
        detailPresented = true
    }

    private func setChatOpen(_ isOpen: Bool) {
        if isOpen {
            guard !detailPresented else { return }
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

    private func maybeSnapToNeighborSun() {
        guard case .branchFocus(let current) = mode else { return }
        let suns = planets.filter { $0.id != .core }.map {
            NeighborSnap.Sun(id: $0.id, position: $0.position3D)
        }
        if let snapped = NeighborSnap.snapTarget(currentFocus: current, yaw: cameraRig.yaw, suns: suns, thresholdRadians: 0.28) {
            BrandHaptics.fire(.light)
            selectCategory(snapped)
        }
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func presentAccount() {
        BrandHaptics.fire(.medium)
        if detailPresented {
            detailPresented = false
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
        if detailPresented {
            detailPresented = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                addToolPresented = true
            }
        } else {
            addToolPresented = true
        }
    }
}

#Preview {
    UniverseMapView()
        .environment(UniverseViewModel())
}
