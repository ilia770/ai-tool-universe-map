import Testing
import Foundation
@testable import MyAIMap

/// A stub `AssistantResponder` that always throws, forcing the `.debugDeepSeek`
/// failure path so the async fallback (and its composer handling) can be tested
/// without hitting the network.
private struct ThrowingResponder: AssistantResponder {
    struct Boom: Error {}
    func reply(to userQuery: String, systemPrompt: String?, apiKey: String?) async throws -> String {
        throw Boom()
    }
}

/// `.serialized` because `askAssistantDeepSeekFailureKeepsInFlightDraft` toggles
/// process-global state (`DeveloperMode` flag in `UserDefaults.standard` + a real
/// Keychain key) to force `.debugDeepSeek`. Running the suite serially keeps that
/// window from bleeding into the sibling tests that assert the `.local` default
/// (`activeBackendIsLocalByDefault`) or the synchronous local reply path.
@Suite("UniverseViewModel — single source of truth", .serialized)
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

    /// Bounded async wait for a MainActor condition. The `.debugDeepSeek` reply is
    /// dispatched on a fire-and-forget `Task` with no handle, so tests can't await
    /// it structurally — instead we poll (per the WS9.4 test plan) while short
    /// sleeps let the awaiting main actor yield to that task. Budget ~1s; returns
    /// whether the condition held in time.
    private func waitUntil(_ condition: () -> Bool, attempts: Int = 500) async -> Bool {
        for _ in 0..<attempts {
            if condition() { return true }
            try? await Task.sleep(nanoseconds: 2_000_000) // 2ms
        }
        return condition()
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

    @Test func askAssistantDecrementsRemainingAndPersists() {
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let store = UniverseStore(defaults: defaults)
        let model = UniverseViewModel(store: store)

        let startRemaining = model.subscription.aiRequestsRemaining
        model.assistantQuery = "what analytics tool should I use"
        model.askAssistant()

        #expect(model.subscription.aiRequestsUsed == 1)
        #expect(model.subscription.aiRequestsRemaining == startRemaining - 1)

        // Usage survives a model reload over the same store.
        let reloaded = UniverseViewModel(store: store)
        #expect(reloaded.subscription.aiRequestsUsed == 1)
    }

    @Test func askAssistantClearsDraftAfterLocalReply() {
        let model = makeModel(sample: true)
        model.assistantQuery = "what analytics tool should I use"

        model.askAssistant()

        #expect(model.assistantQuery == "")
        #expect(model.assistantMessages.contains { $0.role == .user && $0.text == "what analytics tool should I use" })
    }

    // WS9.4: on the async `.debugDeepSeek` FAILURE path the local fallback must NOT
    // re-clear the composer, or it wipes text the user typed while the round-trip
    // was in flight. Forces `.debugDeepSeek` (developer mode + a stored key), injects
    // a throwing responder, types a new draft after send, and asserts it survives.
    @Test func askAssistantDeepSeekFailureKeepsInFlightDraft() async {
        // Force the debug DeepSeek path via its real gates, snapshotting + restoring
        // the process-global state so sibling tests still see the `.local` default.
        let previousDevMode = UserDefaults.standard.object(forKey: DeveloperMode.defaultsKey)
        let previousKey = KeychainStore.load(account: KeychainStore.deepSeekAPIKeyAccount)
        UserDefaults.standard.set(true, forKey: DeveloperMode.defaultsKey)
        KeychainStore.save("sk-test-force-debug", account: KeychainStore.deepSeekAPIKeyAccount)
        defer {
            if let previousDevMode {
                UserDefaults.standard.set(previousDevMode, forKey: DeveloperMode.defaultsKey)
            } else {
                UserDefaults.standard.removeObject(forKey: DeveloperMode.defaultsKey)
            }
            if let previousKey {
                KeychainStore.save(previousKey, account: KeychainStore.deepSeekAPIKeyAccount)
            } else {
                KeychainStore.delete(account: KeychainStore.deepSeekAPIKeyAccount)
            }
        }

        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let model = UniverseViewModel(
            store: UniverseStore(defaults: defaults),
            assistantResponder: ThrowingResponder()
        )
        model.loadSampleUniverse()
        // Precondition: the gates above actually route to the async DeepSeek branch.
        #expect(model.activeBackend == .debugDeepSeek)

        // Send query A. The `.debugDeepSeek` branch spawns the fire-and-forget task
        // and synchronously clears the SENT query before returning — no suspension
        // happens here, so the task cannot have run yet.
        model.assistantQuery = "what analytics tool should I use"
        model.askAssistant()
        #expect(model.assistantQuery == "")

        // User types a new draft B while the async round-trip is still in flight.
        model.assistantQuery = "B"

        // Await the async failure fallback (first suspension lets the task run).
        let appended = await waitUntil { model.assistantMessages.count >= 2 }
        #expect(appended)

        // The in-flight draft must survive; a local fallback reply must be appended.
        #expect(model.assistantQuery == "B")
        #expect(model.assistantMessages.count == 2)
        #expect(model.assistantMessages.first?.role == .user)
        #expect(model.assistantMessages.last?.role == .assistant)
        #expect(model.assistantMessages.last?.text.isEmpty == false)
    }

    @Test func attachmentOnlyAskDoesNotConsumeRequest() {
        let model = makeModel()
        let startUsed = model.subscription.aiRequestsUsed
        model.assistantQuery = "see attached"
        model.askAssistant(attachmentOnly: true)
        #expect(model.subscription.aiRequestsUsed == startUsed)
    }

    @Test func activeBackendIsLocalByDefault() {
        // Release / normal-user default: no developer mode → local backend.
        let model = makeModel()
        #expect(model.activeBackend == .local)
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
    }

    @Test func defaultClarityMatchesWebInitialState() {
        // Web parity: AIToolUniverseMap.tsx:150 — useState<MapClarityMode>('focus').
        let model = makeModel()
        #expect(model.clarityMode == .focus)
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

    @Test func deletingSelectedToolWhileInDetailExitsDetailMode() {
        // R5: the compact detail sheet is derived from `universeMode.isDetailOpen`.
        // Removing the selected tool from the detail sheet must drop the model out
        // of `.detail`, otherwise the derived sheet would outlive the navigation
        // state. We assert the state layer here; the View boolean syncs off this.
        let model = makeModel(sample: true)
        #expect(model.focusTool("posthog"))
        model.universeMode = .detail(.analytics, "posthog")
        #expect(model.universeMode.isDetailOpen)

        #expect(model.deleteTool("posthog"))

        #expect(!model.universeMode.isDetailOpen)
        #expect(model.universeMode.selectedToolID != "posthog")
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

    @Test func distinctToolsSharingOneHostBothCoexist() {
        let model = makeModel()
        let initialCount = model.allTools.count

        #expect(model.addCustomTool(name: "First Repo", urlString: "https://github.com/first", category: .analytics))
        #expect(model.addCustomTool(name: "Second Repo", urlString: "https://github.com/second", category: .analytics))

        #expect(model.allTools.count == initialCount + 2)
        #expect(model.visibleAllTools.contains { $0.name == "First Repo" })
        #expect(model.visibleAllTools.contains { $0.name == "Second Repo" })
    }

    @Test func sameNameSharingOneHostStillDedupsRegardlessOfCase() {
        let model = makeModel()
        let initialCount = model.allTools.count

        #expect(model.addCustomTool(name: "Shared Tool", urlString: "https://github.com/first", category: .analytics))
        #expect(model.addCustomTool(name: "  shared   tool ", urlString: "https://github.com/second", category: .analytics))

        #expect(model.allTools.count == initialCount + 1)
        #expect(model.selectedTool?.name == "Shared Tool")
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
            customCategories: [],
            hidden: [PlanetData.centralCoreToolID, "some-tool"],
            hapticsEnabled: true,
            hasSeenOnboarding: true,
            subscription: .free
        )

        let model = UniverseViewModel(store: store)
        #expect(!model.hiddenToolIDs.contains(PlanetData.centralCoreToolID))
        #expect(model.hiddenToolIDs.contains("some-tool"))

        // The sanitized set is re-persisted, so a reload stays clean.
        let reloaded = UniverseViewModel(store: store)
        #expect(!reloaded.hiddenToolIDs.contains(PlanetData.centralCoreToolID))
    }

    // MARK: - First-run onboarding flag

    @Test func freshUniverseHasNotSeenOnboarding() {
        let model = makeModel()
        #expect(!model.hasSeenOnboarding)
    }

    @Test func markOnboardingSeenPersistsAcrossReload() {
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let store = UniverseStore(defaults: defaults)
        let model = UniverseViewModel(store: store)
        #expect(!model.hasSeenOnboarding)

        model.markOnboardingSeen()
        #expect(model.hasSeenOnboarding)

        // A relaunch (fresh model on the same store) must not re-show onboarding.
        let reloaded = UniverseViewModel(store: store)
        #expect(reloaded.hasSeenOnboarding)
    }

    @Test func onboardingFlagIsIndependentOfEmptiness() {
        let model = makeModel()
        model.markOnboardingSeen()
        // Completed onboarding but added nothing: still empty, but no re-show.
        #expect(model.hasSeenOnboarding)
        #expect(model.isUniverseEmpty)
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

    // MARK: - Custom (user/AI-created) branches — blueprint §8

    @Test func createBranchReturnsResolvableCategory() {
        let model = makeModel()
        let id = model.createBranch(name: "Voice Agents")
        #expect(id.rawValue == "voice-agents")
        #expect(!id.isBuiltin)
        // Resolvable everywhere category(_:) is called.
        let resolved = UniverseSeed.category(id)
        #expect(resolved.id == id)
        #expect(resolved.shortName == "Voice Agents")
        #expect(model.allCategories.contains { $0.id == id })
    }

    @Test func createBranchSlugCollisionGetsUniqueID() {
        let model = makeModel()
        let first = model.createBranch(name: "Ops")
        let second = model.createBranch(name: "Ops")
        #expect(first.rawValue == "ops")
        #expect(second.rawValue == "ops-2")
        #expect(model.customCategories.count == 2)
    }

    @Test func toolAddedToCustomBranchIsVisibleAndSearchable() {
        let model = makeModel()
        let id = model.createBranch(name: "Voice Agents")
        #expect(model.addCustomTool(name: "Vapi", urlString: "vapi.ai", category: id))

        let added = model.visibleAllTools.first { $0.name == "Vapi" }
        #expect(added?.category == id)

        model.searchQuery = "Vapi"
        #expect(model.searchResults.contains { $0.name == "Vapi" })
    }

    @Test func customBranchPlanetRendersOnceItHasATool() {
        let model = makeModel()
        let id = model.createBranch(name: "Voice Agents")
        // No tool yet → no planet (makePlanets drops empty categories).
        #expect(!PlanetData.makePlanets(categories: model.allCategories, tools: model.visibleAllTools)
            .contains { $0.id == id })

        _ = model.addCustomTool(name: "Vapi", urlString: "vapi.ai", category: id)
        let planets = PlanetData.makePlanets(categories: model.allCategories, tools: model.visibleAllTools)
        #expect(planets.contains { $0.id == id })
    }

    @Test func customBranchPersistsAcrossReload() {
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let store = UniverseStore(defaults: defaults)
        let model = UniverseViewModel(store: store)
        let id = model.createBranch(name: "Voice Agents")
        _ = model.addCustomTool(name: "Vapi", urlString: "vapi.ai", category: id)

        let reloaded = UniverseViewModel(store: store)
        #expect(reloaded.customCategories.contains { $0.id == id })
        // Registry is repopulated on load so resolution stays correct.
        #expect(UniverseSeed.category(id).shortName == "Voice Agents")
        #expect(reloaded.visibleAllTools.contains { $0.name == "Vapi" })
    }

    @Test func resetClearsCustomBranches() {
        let model = makeModel()
        let id = model.createBranch(name: "Voice Agents")
        _ = model.addCustomTool(name: "Vapi", urlString: "vapi.ai", category: id)
        model.resetUniverse()
        #expect(model.customCategories.isEmpty)
        #expect(model.allCategories.allSatisfy { $0.id.isBuiltin })
    }
}
