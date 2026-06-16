import Testing
@testable import MyAIMap

@Suite("UniverseViewModel — single source of truth")
@MainActor
struct UniverseViewModelTests {

    @Test func defaultStateShowsFounderCore() {
        let model = UniverseViewModel()
        #expect(model.selection.activeCategory == .core)
        #expect(model.selectedTool.id == "founder-os")
        #expect(model.selection.viewMode == .overview)
    }

    @Test func defaultClarityMatchesWebInitialState() {
        // Web parity: AIToolUniverseMap.tsx:150 — useState<MapClarityMode>('focus').
        let model = UniverseViewModel()
        #expect(model.clarityMode == .focus)
    }

    @Test func selectCategoryAutoSelectsItsFirstTool() {
        // Parity with Phase 1 UniverseScreen.onChange(of: selectedCategory).
        let model = UniverseViewModel()
        model.selectCategory(.design)
        #expect(model.selection.activeCategory == .design)
        let expected = UniverseSeed.tools(in: .design).first?.id
        #expect(expected != nil)
        #expect(model.selection.selectedToolID == expected)
    }

    @Test func selectToolUpdatesSelectedTool() {
        let model = UniverseViewModel()
        model.selectCategory(.design)
        guard let second = UniverseSeed.tools(in: .design).dropFirst().first else {
            Issue.record("seed needs >= 2 design tools (UniverseLayoutTests guarantees this)")
            return
        }
        model.selectTool(second.id)
        #expect(model.selectedTool.id == second.id)
    }

    @Test func focusToolSelectsItsToolAndCategory() {
        let model = UniverseViewModel()
        guard let mediaTool = UniverseSeed.tools(in: .media).first else {
            Issue.record("seed needs a media tool")
            return
        }

        let focused = model.focusTool(mediaTool.id)

        #expect(focused)
        #expect(model.selection.activeCategory == .media)
        #expect(model.selection.selectedToolID == mediaTool.id)
        #expect(model.clarityMode == .focus)
    }

    @Test func focusToolReturnsFalseForUnknownID() {
        let model = UniverseViewModel()
        #expect(model.focusTool("missing-tool") == false)
        #expect(model.selection.activeCategory == .core)
        #expect(model.selection.selectedToolID == "founder-os")
    }

    @Test func reselectingActiveCategoryKeepsToolSelection() {
        // Phase 1 parity: .onChange(of:) only fired on actual change, so
        // re-tapping the active chip must not reset the chosen tool.
        let model = UniverseViewModel()
        model.selectCategory(.design)
        guard let second = UniverseSeed.tools(in: .design).dropFirst().first else {
            Issue.record("seed needs >= 2 design tools (UniverseLayoutTests guarantees this)")
            return
        }
        model.selectTool(second.id)
        model.selectCategory(.design)
        #expect(model.selection.selectedToolID == second.id)
    }

    @Test func visibleToolsFallBackToCoreWhenCategoryEmpty() {
        // Mirrors Phase 1: empty category shows core tools instead of nothing.
        let model = UniverseViewModel()
        #expect(!model.visibleTools.isEmpty)
    }

    @Test func selectedToolSurvivesUnknownID() {
        let model = UniverseViewModel()
        model.selectTool("does-not-exist")
        // Falls back to first visible tool, never crashes.
        #expect(!model.selectedTool.id.isEmpty)
    }

    @Test func hoverIsSettableAndClearable() {
        let model = UniverseViewModel()
        model.setHover("figma")
        #expect(model.selection.hoveredToolID == "figma")
        model.setHover(nil)
        #expect(model.selection.hoveredToolID == nil)
    }

    @Test func searchResultsMatchNameCaseInsensitive() {
        let model = UniverseViewModel()
        model.searchQuery = "FOUNDER"
        #expect(model.searchResults.contains { $0.id == "founder-os" })
    }

    @Test func emptySearchQueryReturnsNoResults() {
        let model = UniverseViewModel()
        model.searchQuery = "   "
        #expect(model.searchResults.isEmpty)
    }

    @Test func focusFirstSearchMatchSelectsToolAndItsCategory() {
        let model = UniverseViewModel()
        guard let designTool = UniverseSeed.tools(in: .design).first else {
            Issue.record("seed needs a design tool")
            return
        }
        model.searchQuery = designTool.name
        let focused = model.focusFirstSearchMatch()
        #expect(focused)
        #expect(model.selection.selectedToolID == designTool.id)
        #expect(model.selection.activeCategory == designTool.category)
    }

    @Test func focusFirstSearchMatchReturnsFalseOnNoMatch() {
        let model = UniverseViewModel()
        model.searchQuery = "zzz-no-such-tool"
        #expect(model.focusFirstSearchMatch() == false)
    }

    // MARK: - Delete (P2)

    @Test func deleteToolHidesItFromAllToolLists() {
        let model = UniverseViewModel()
        guard let victim = UniverseSeed.tools(in: .design).dropFirst().first else {
            Issue.record("seed needs >= 2 design tools")
            return
        }
        model.deleteTool(victim.id)
        #expect(model.tools.contains { $0.id == victim.id } == false)
        #expect(model.tools(in: .design).contains { $0.id == victim.id } == false)
        #expect(model.searchResults.contains { $0.id == victim.id } == false)
    }

    @Test func deletingSelectedToolMovesSelectionToNeighbour() {
        let model = UniverseViewModel()
        model.selectCategory(.design)
        let designTools = UniverseSeed.tools(in: .design)
        guard designTools.count >= 2 else {
            Issue.record("seed needs >= 2 design tools")
            return
        }
        model.selectTool(designTools[0].id)
        model.deleteTool(designTools[0].id)
        // Selection must still be valid and must not be the deleted id.
        #expect(model.selectedTool.id != designTools[0].id)
        #expect(model.tools.contains { $0.id == model.selectedTool.id })
    }

    @Test func deleteToolIsIgnoredForUnknownID() {
        let model = UniverseViewModel()
        let before = model.tools.count
        model.deleteTool("does-not-exist")
        #expect(model.tools.count == before)
    }

    @Test func deleteToolNotifiesDeletionSink() {
        let model = UniverseViewModel()
        var captured: [ToolDeletion] = []
        model.deletionSink = { captured.append($0) }
        guard let victim = UniverseSeed.tools(in: .media).first else {
            Issue.record("seed needs a media tool")
            return
        }
        model.deleteTool(victim.id)
        #expect(captured.count == 1)
        #expect(captured.first?.toolID == victim.id)
        #expect(captured.first?.toolName == victim.name)
        #expect(captured.first?.category == victim.category)
    }

    @Test func deleteFounderCoreIsRejected() {
        let model = UniverseViewModel()
        model.deleteTool("founder-os")
        #expect(model.tools.contains { $0.id == "founder-os" })
    }
}
