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

    @Test func loadSampleUnhidesPreviouslyDeletedSampleTool() {
        // F1: re-loading the sample restores a sample tool the user deleted,
        // even though it's still in customTools (so it was being skipped).
        let model = makeModel(sample: true)
        #expect(model.deleteTool("posthog"))
        #expect(model.removedTools.contains { $0.id == "posthog" })

        #expect(model.loadSampleUniverse())
        #expect(!model.removedTools.contains { $0.id == "posthog" })
    }

    @Test func hasStoredDataReflectsPersistenceNotMapEmptiness() {
        // F2: hiding the only tool makes the map empty while data persists, so
        // hasStoredData (which gates Reset) must stay true.
        let model = makeModel()
        #expect(!model.hasStoredData)

        #expect(model.addCustomTool(name: "Solo Tool", urlString: "example.com", category: .analytics))
        let id = model.allTools.first { $0.name == "Solo Tool" }!.id
        #expect(model.deleteTool(id))

        #expect(model.isUniverseEmpty)
        #expect(model.hasStoredData)
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

    @Test func renderModeDefaultsToReadableGraph2D() {
        let model = makeModel()
        #expect(model.renderMode == .graph2D)
    }

    @Test func renderModePersistsAcrossModelReloads() {
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let store = UniverseStore(defaults: defaults)

        let first = UniverseViewModel(store: store)
        first.renderMode = .spatial3D

        let reloaded = UniverseViewModel(store: store)
        #expect(reloaded.renderMode == .spatial3D)
    }

    @Test func hapticsSettingPersistsAcrossModelReloads() {
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let store = UniverseStore(defaults: defaults)

        let first = UniverseViewModel(store: store)
        first.hapticsEnabled = false

        let reloaded = UniverseViewModel(store: store)
        #expect(!reloaded.hapticsEnabled)
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

    @Test func addedToolStoresSourceDomainWhenWebsiteExists() {
        let model = makeModel()

        #expect(model.addCustomTool(name: "PostHog", urlString: "https://www.posthog.com", category: .analytics))

        let tool = model.visibleAllTools.first { $0.name == "PostHog" }
        #expect(tool?.category == .analytics)
        #expect(tool?.url?.absoluteString == "https://www.posthog.com")
        #expect(tool?.logoDomain == "posthog.com")
        #expect(tool?.summary.contains("Source domain: posthog.com") == true)
    }

    @Test func duplicateAddFocusesExistingVisibleToolInsteadOfCreatingCopy() {
        let model = makeModel(sample: true)
        let initialCount = model.allTools.count

        #expect(model.addCustomTool(name: "PostHog", urlString: "https://www.posthog.com", category: .analytics))

        #expect(model.allTools.count == initialCount)
        #expect(model.selectedTool?.id == "posthog")
        #expect(!model.allTools.contains { $0.id == "posthog-2" })
    }

    @Test func duplicateAddRestoresHiddenToolInsteadOfCreatingCopy() {
        let model = makeModel(sample: true)
        let initialCount = model.allTools.count
        #expect(model.deleteTool("posthog"))

        #expect(model.addCustomTool(name: "PostHog", urlString: "", category: .analytics))

        #expect(model.allTools.count == initialCount)
        #expect(!model.removedTools.contains { $0.id == "posthog" })
        #expect(model.selectedTool?.id == "posthog")
        #expect(model.activityHistory.contains { $0.kind == .restored && $0.toolID == "posthog" })
    }

    @Test func httpWebsiteIsStoredAsHttpsSoDetailCanOpenIt() {
        let model = makeModel()

        #expect(model.addCustomTool(name: "HTTP Tool", urlString: "http://example.com/docs", category: .analytics))

        let tool = model.visibleAllTools.first { $0.name == "HTTP Tool" }
        #expect(tool?.url?.scheme == "https")
        #expect(tool?.url?.absoluteString == "https://example.com/docs")
        #expect(tool?.logoDomain == "example.com")
    }

    @Test func addedToolWithoutWebsiteIsMarkedUnverified() {
        let model = makeModel()

        #expect(model.addCustomTool(name: "Random User Tool", urlString: "", category: .design))

        let tool = model.visibleAllTools.first { $0.name == "Random User Tool" }
        #expect(tool?.url == nil)
        #expect(tool?.logoDomain == nil)
        #expect(tool?.summary.contains("Website not provided") == true)
        #expect(tool?.classification?.reason.contains("without a website") == true)
    }

    @Test func assistantCanReferenceToolAfterSuccessfulAdd() {
        let model = makeModel()

        #expect(model.addCustomTool(name: "Random User Tool", urlString: "", category: .design))
        model.assistantQuery = "Random User Tool"
        model.askAssistant()

        let assistantReply = model.assistantMessages.last
        #expect(assistantReply?.role == .assistant)
        #expect(assistantReply?.matchIDs.contains("random-user-tool") == true)
        #expect(assistantReply?.text.contains("I did not find this service") == false)
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

    // MARK: - Defensive: core tool can never be stranded by a stale hidden set

    @Test func loadSanitizesHiddenCoreToolSoSelectionNeverStrands() {
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let store = UniverseStore(defaults: defaults)
        // Simulate a stale/corrupt persisted state where the core tool was hidden.
        store.save(
            tools: [],
            hidden: [PlanetData.centralCoreToolID, "some-tool"],
            renderMode: .graph2D,
            hapticsEnabled: true
        )

        let model = UniverseViewModel(store: store)
        #expect(!model.hiddenToolIDs.contains(PlanetData.centralCoreToolID))
        #expect(model.hiddenToolIDs.contains("some-tool"))

        // The sanitized set is re-persisted, so a reload stays clean.
        let reloaded = UniverseViewModel(store: store)
        #expect(!reloaded.hiddenToolIDs.contains(PlanetData.centralCoreToolID))
    }

    // U1: the assistant can't read attachments, so an attachment-only send gets
    // an honest reply instead of matching tools against the placeholder text.
    @Test func attachmentOnlyMessageGetsHonestCannotReadReply() {
        let model = makeModel(sample: true)
        model.assistantQuery = "Attached photo"
        model.askAssistant(attachmentOnly: true)

        let last = model.assistantMessages.last
        #expect(last?.role == .assistant)
        #expect(last?.matchIDs.isEmpty == true)
        #expect(last?.text.contains("can't read attachments") == true)
    }
}
