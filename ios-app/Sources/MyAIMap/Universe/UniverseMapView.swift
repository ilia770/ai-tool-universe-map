import SwiftUI
import UIKit

/// Production-style native 3D universe map: RealityKit scene + SwiftUI glass UI.
struct UniverseMapView: View {
    @Environment(UniverseViewModel.self) private var model
    @State private var sceneController = UniverseSceneController()
    @State private var cameraRig = CameraRigController()
    @State private var gestureController = UniverseGestureController()
    @State private var mode: UniverseMode = .overview
    @State private var modeBeforeDetail: UniverseMode?
    @State private var detailPresented = false
    @State private var accountPresented = false
    @State private var addToolPresented = false

    @State private var planets: [PlanetData] = []

    private func rebuildPlanets() {
        planets = PlanetData.makePlanets(categories: UniverseSeed.categories, tools: model.visibleAllTools)
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
        return model.selectedTool
    }

    var body: some View {
        ZStack {
            UniverseRealityView(
                planets: planets,
                mode: mode,
                visualizationStyle: model.visualizationStyle,
                sceneController: sceneController,
                cameraRig: cameraRig,
                gestureController: gestureController,
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
                onChatActivityChange: setChatOpen,
                onDetails: presentDetail,
                onAccount: presentAccount,
                onAddTool: presentAddTool
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .preferredColorScheme(.dark)
        .onAppear {
            BrandHaptics.isEnabled = model.hapticsEnabled
            BrandHaptics.prepare(.light, .medium, .heavy, .success)
            mode = navigationModeForSelection()
            focusCamera(for: mode, animated: false)
        }
        .onChange(of: model.hapticsEnabled) { _, isEnabled in
            BrandHaptics.isEnabled = isEnabled
        }
        .onChange(of: mode) { _, newMode in
            focusCamera(for: newMode, animated: true)
        }
        .onChange(of: model.selection) { _, selection in
            reconcileMode(with: selection)
        }
        .onChange(of: detailPresented) { _, isPresented in
            if isPresented {
                mode = .detail(selectedTool.category, selectedTool.id)
            } else if mode.isDetailOpen {
                mode = modeBeforeDetail ?? navigationModeForSelection()
                modeBeforeDetail = nil
            }
        }
        .sheet(isPresented: $detailPresented) {
            RootSheet()
                .presentationDetents([.fraction(0.72), .large])
                .presentationBackgroundInteraction(.enabled(upThrough: .fraction(0.72)))
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(42)
        }
        .sheet(isPresented: $accountPresented) {
            AccountSettingsSheet()
                .environment(model)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(42)
        }
        .sheet(isPresented: $addToolPresented) {
            AddToolSheet()
                .environment(model)
                .presentationDetents([.fraction(0.72), .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(42)
        }
        .onAppear { if planets.isEmpty { rebuildPlanets() } }
        .onChange(of: model.visibleAllTools.count) { _, _ in rebuildPlanets() }
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

        withAnimation(BrandMotion.flow) {
            model.selectCategory(id)
            mode = id == .core ? .overview : .branchFocus(id)
        }
    }

    private func focusToolFromMap(_ id: String) {
        guard let tool = model.visibleAllTools.first(where: { $0.id == id }) else { return }
        guard model.selection.selectedToolID != id else {
            if mode == .toolSelected(tool.category, id) {
                presentDetail()
            } else {
                BrandHaptics.fire(.light)
                mode = .toolSelected(tool.category, id)
            }
            return
        }
        BrandHaptics.fire(.medium)
        withAnimation(BrandMotion.flow) {
            _ = model.focusTool(id)
            mode = .toolSelected(tool.category, id)
        }
    }

    private func resetToOverview() {
        dismissKeyboard()
        guard mode != .overview else {
            cameraRig.overview(animated: true)
            return
        }
        BrandHaptics.fireRich(.pocketClose)
        withAnimation(BrandMotion.flow) {
            model.selectCategory(.core)
            mode = .overview
        }
    }

    private func handleEmptySpaceTap() {
        dismissKeyboard()
        if mode.isChatOpen {
            restoreNavigationMode(animated: true)
        } else if mode.isDetailOpen {
            return
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

    private func presentDetail() {
        BrandHaptics.fire(.medium)
        if !mode.isDetailOpen {
            modeBeforeDetail = mode
        }
        mode = .detail(selectedTool.category, selectedTool.id)
        detailPresented = true
    }

    private func setChatOpen(_ isOpen: Bool) {
        if isOpen {
            guard !detailPresented else { return }
            let category = model.selection.activeCategory == .core ? nil : model.selection.activeCategory
            let toolID = model.selection.selectedToolID == "founder-os" ? nil : model.selection.selectedToolID
            mode = .chatOpen(category, toolID)
        } else if mode.isChatOpen {
            restoreNavigationMode(animated: true)
        }
    }

    private func restoreNavigationMode(animated: Bool) {
        if case .chatOpen(let category, let toolID) = mode,
           let category,
           let toolID,
           model.visibleAllTools.contains(where: { $0.id == toolID && $0.category == category }) {
            mode = .toolSelected(category, toolID)
            return
        }
        mode = navigationModeForSelection()
    }

    private func navigationModeForSelection() -> UniverseMode {
        let category = model.selection.activeCategory
        guard category != .core else { return .overview }
        return .branchFocus(category)
    }

    private func reconcileMode(with selection: UniverseSelection) {
        guard !mode.isChatOpen else { return }

        if mode.isDetailOpen {
            guard let tool = model.visibleAllTools.first(where: { $0.id == selection.selectedToolID }) else { return }
            modeBeforeDetail = .toolSelected(tool.category, tool.id)
            if mode != .detail(tool.category, tool.id) {
                mode = .detail(tool.category, tool.id)
            }
            return
        }

        if mode.selectedToolID != nil,
           let tool = model.visibleAllTools.first(where: { $0.id == selection.selectedToolID }),
           mode != .toolSelected(tool.category, tool.id) {
            mode = .toolSelected(tool.category, tool.id)
            return
        }

        if mode.selectedToolID == nil, mode.focusedCategory != selection.activeCategory {
            mode = selection.activeCategory == .core ? .overview : .branchFocus(selection.activeCategory)
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
        BrandHaptics.fire(.medium)
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
