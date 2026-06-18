import Testing
import Foundation
@testable import MyAIMap

@Suite("UniverseViewModel — single source of truth")
@MainActor
struct UniverseViewModelTests {

    /// A model backed by an isolated, empty store. The product default is an
    /// empty universe, so seed-dependent tests opt in via `sample: true`.
    private func makeModel(sample: Bool = false) -> UniverseViewModel {
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let model = UniverseViewModel(store: UniverseStore(defaults: defaults))
        if sample { model.loadSampleUniverse() }
        return model
    }

    // MARK: - Empty-by-default product model

    @Test func freshUniverseIsEmpty() {
        let model = makeModel()
        #expect(model.isUniverseEmpty)
        #expect(model.allTools.isEmpty)
        #expect(model.selectedTool == nil)
        // Overview is still the default framing even with nothing to show.
        #expect(model.selection.activeCategory == .core)
    }

    @Test func loadSampleUniversePopulatesFromSeed() {
        let model = makeModel()
        #expect(model.loadSampleUniverse())
        #expect(!model.isUniverseEmpty)
        #expect(model.allTools.count == UniverseSeed.tools.count)
        // Loading again is a no-op (nothing new to add).
        #expect(model.loadSampleUniverse() == false)
    }

    @Test func resetUniverseClearsEverything() {
        let model = makeModel(sample: true)
        #expect(!model.isUniverseEmpty)
        model.resetUniverse()
        #expect(model.isUniverseEmpty)
        #expect(model.allTools.isEmpty)
        #expect(model.universeMode == .overview)
    }

    @Test func addedToolPersistsAcrossModelReloads() {
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let store = UniverseStore(defaults: defaults)

        let first = UniverseViewModel(store: store)
        #expect(first.addCustomTool(name: "Persisted Tool", urlString: "example.com", category: .analytics))

        // A fresh model over the same store sees the saved universe.
        let reloaded = UniverseViewModel(store: store)
        #expect(reloaded.allTools.contains { $0.name == "Persisted Tool" })
        #expect(!reloaded.isUniverseEmpty)
    }

    @Test func deletionPersistsAcrossModelReloads() {
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let store = UniverseStore(defaults: defaults)

        let first = UniverseViewModel(store: store)
        first.loadSampleUniverse()
        #expect(first.deleteTool("posthog"))

        let reloaded = UniverseViewModel(store: store)
        #expect(reloaded.removedTools.contains { $0.id == "posthog" })
        reloaded.searchQuery = "posthog"
        #expect(reloaded.searchResults.isEmpty)
    }

    // MARK: - Selection / navigation (seed-backed)

    @Test func sampleStateShowsFounderCore() {
        let model = makeModel(sample: true)
        #expect(model.selection.activeCategory == .core)
        #expect(model.selectedTool?.id == "founder-os")
        #expect(model.selection.viewMode == .overview)
    }

    @Test func defaultClarityMatchesWebInitialState() {
        // Web parity: AIToolUniverseMap.tsx:150 — useState<MapClarityMode>('focus').
        let model = makeModel()
        #expect(model.clarityMode == .focus)
    }

    @Test func selectCategoryAutoSelectsItsFirstTool() {
        let model = makeModel(sample: true)
        model.selectCategory(.design)
        #expect(model.selection.activeCategory == .design)
        let expected = UniverseSeed.tools(in: .design).first?.id
        #expect(expected != nil)
        #expect(model.selection.selectedToolID == expected)
    }

    @Test func selectToolUpdatesSelectedTool() {
        let model = makeModel(sample: true)
        model.selectCategory(.design)
        guard let second = UniverseSeed.tools(in: .design).dropFirst().first else {
            Issue.record("seed needs >= 2 design tools (UniverseLayoutTests guarantees this)")
            return
        }
        model.selectTool(second.id)
        #expect(model.selectedTool?.id == second.id)
    }

    @Test func focusToolSelectsItsToolAndCategory() {
        let model = makeModel(sample: true)
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
        let model = makeModel(sample: true)
        #expect(model.focusTool("missing-tool") == false)
        #expect(model.selection.activeCategory == .core)
        #expect(model.selection.selectedToolID == "founder-os")
    }

    @Test func reselectingActiveCategoryKeepsToolSelection() {
        let model = makeModel(sample: true)
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
        let model = makeModel(sample: true)
        #expect(!model.visibleTools.isEmpty)
    }

    @Test func selectedToolSurvivesUnknownID() {
        let model = makeModel(sample: true)
        model.selectTool("does-not-exist")
        #expect(model.selectedTool?.id.isEmpty == false)
    }

    @Test func hoverIsSettableAndClearable() {
        let model = makeModel(sample: true)
        model.setHover("figma")
        #expect(model.selection.hoveredToolID == "figma")
        model.setHover(nil)
        #expect(model.selection.hoveredToolID == nil)
    }

    @Test func searchResultsMatchNameCaseInsensitive() {
        let model = makeModel(sample: true)
        model.searchQuery = "FOUNDER"
        #expect(model.searchResults.contains { $0.id == "founder-os" })
    }

    @Test func emptyUniverseHasNoSearchResults() {
        let model = makeModel()
        model.searchQuery = "founder"
        #expect(model.searchResults.isEmpty)
    }

    @Test func emptySearchQueryReturnsNoResults() {
        let model = makeModel(sample: true)
        model.searchQuery = "   "
        #expect(model.searchResults.isEmpty)
    }

    @Test func focusFirstSearchMatchSelectsToolAndItsCategory() {
        let model = makeModel(sample: true)
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
        let model = makeModel(sample: true)
        model.searchQuery = "zzz-no-such-tool"
        #expect(model.focusFirstSearchMatch() == false)
    }

    @Test func deleteToolHidesItFromSearchAndRecordsHistory() {
        let model = makeModel(sample: true)
        #expect(model.focusTool("posthog"))

        #expect(model.deleteTool("posthog"))

        model.searchQuery = "posthog"
        #expect(model.searchResults.isEmpty)
        #expect(model.removedTools.contains { $0.id == "posthog" })
        #expect(model.activityHistory.contains { $0.kind == .removed && $0.toolID == "posthog" })
    }

    @Test func restoreToolReturnsItToSearch() {
        let model = makeModel(sample: true)
        #expect(model.deleteTool("posthog"))
        #expect(model.restoreTool("posthog"))

        model.searchQuery = "posthog"
        #expect(model.searchResults.contains { $0.id == "posthog" })
        #expect(model.activityHistory.contains { $0.kind == .restored && $0.toolID == "posthog" })
    }

    @Test func addCustomToolFocusesAndRecordsIt() {
        let model = makeModel()

        #expect(model.addCustomTool(name: "New Analytics Tool", urlString: "example.com", category: .analytics))

        #expect(model.selectedTool?.name == "New Analytics Tool")
        #expect(model.selection.activeCategory == .analytics)
        #expect(model.activityHistory.contains { $0.kind == .added && $0.title.contains("New Analytics Tool") })
    }

    @Test func assistantMissingToolDoesNotInventMatch() {
        let model = makeModel(sample: true)
        model.assistantQuery = "some unknown service"

        model.askAssistant()

        let assistantReply = model.assistantMessages.last
        #expect(assistantReply?.role == .assistant)
        #expect(assistantReply?.matchIDs.isEmpty == true)
        #expect(assistantReply?.text.contains("website URL") == true)
    }
}
