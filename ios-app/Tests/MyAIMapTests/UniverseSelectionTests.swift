import Testing
@testable import MyAIMap

@Suite("UniverseSelection — defaults and view-mode derivation")
struct UniverseSelectionTests {

    @Test func defaultsMatchPhase1Behaviour() {
        let selection = UniverseSelection()
        #expect(selection.activeCategory == .core)
        #expect(selection.selectedToolID == "founder-os")
        #expect(selection.hoveredToolID == nil)
    }

    @Test func viewModeIsOverviewForCore() {
        let selection = UniverseSelection()
        #expect(selection.viewMode == .overview)
    }

    @Test func viewModeIsPocketForNonCoreCategory() {
        var selection = UniverseSelection()
        selection.activeCategory = .design
        #expect(selection.viewMode == .pocket)
    }

    @Test func clarityModeHasWebParityCases() {
        // Web parity: F / C / A keyboard shortcuts.
        #expect(ClarityMode.allCases == [.focus, .context, .atlas])
    }

    @Test func graph2DStaysStableDefaultAnd3DIsExperimental() {
        #expect(UniverseRenderMode.allCases.first == .graph2D)
        #expect(UniverseRenderMode.spatial3D.isExperimental)
    }

    @Test func default3DTuningStaysSubtleWhileExperimental() {
        #expect(VisualizationStyle.orbitalGlass.nodeScale <= 0.9)
        #expect(VisualizationStyle.orbitalGlass.categoryScale <= 0.85)
        #expect(VisualizationStyle.orbitalGlass.glowBoost <= 0.75)
    }
}
