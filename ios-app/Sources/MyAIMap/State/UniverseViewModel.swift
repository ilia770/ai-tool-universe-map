import Foundation
import Observation

/// Single source of truth for universe UI state, per the Phase 2
/// decision log: `@Observable` class injected via environment — not
/// `@EnvironmentObject`. Owns selection, active category, clarity
/// mode, and search query. Never touches the RealityKit graph;
/// `CameraRigController` owns the camera entity.
@MainActor
@Observable
final class UniverseViewModel {
    /// SINGLE SOURCE OF TRUTH for navigation (see docs/UI_STATE_MACHINE.md).
    /// `selectedCategory` and `selectedTool` are projected from this — nothing
    /// else stores them, so map / chips / rail / card can never desync.
    var universeMode: UniverseMode = .overview

    /// The compact detail presentation route. Its optional value is the sole
    /// source for the compact sheet; `universeMode` remains the sole stored map
    /// selection value.
    private(set) var detailRoute: DetailRoute?

    /// Hover is independent of the navigation mode.
    // Web parity: AIToolUniverseMap.tsx:150 initialises mapClarity to 'focus'.
    var clarityMode: ClarityMode = .focus
    var searchQuery: String = ""
    var assistantQuery: String = ""
    var assistantMessages: [AssistantMessage] = []
    var visualizationStyle: VisualizationStyle = .orbitalGlass
    var appLanguage: AppLanguage = .system
    var hapticsEnabled: Bool = true {
        didSet {
            guard oldValue != hapticsEnabled else { return }
            persistPreferences()
        }
    }
    /// PLACEHOLDER plan / usage state (no billing). Persisted; usage increments
    /// on each Ask-AI send so the "remaining" count visibly moves.
    private(set) var subscription: SubscriptionState = .free
    private(set) var activityHistory: [UniverseActivity] = []
    private(set) var hiddenToolIDs: Set<String> = []
    private(set) var customTools: [Tool] = []
    /// User/AI-created branches (blueprint §8). Persisted alongside custom tools
    /// and mirrored into `UniverseSeed`'s registry so the seed's `category(_:)`
    /// resolver can label and color them everywhere.
    private(set) var customCategories: [ToolCategory] = []

    /// True once the user has completed (or skipped) first-run onboarding.
    /// Persisted so the one-screen overlay shows only on a true first launch.
    /// Independent of `isUniverseEmpty` — a user who onboards but adds nothing
    /// must not see the overlay again (they see the empty-universe state).
    private(set) var hasSeenOnboarding: Bool = false

    /// Non-nil means persisted catalog data needs an explicit recovery decision.
    /// The app must not silently turn this state into a fresh empty universe.
    private(set) var catalogRecovery: CatalogRecovery?

    @ObservationIgnored private let catalogRepository: (any CatalogRepository)?
    @ObservationIgnored private let preferences: UserDefaultsPreferences?
    @ObservationIgnored private let migrationCoordinator: CatalogMigrationCoordinator?
    /// Test-only compatibility path while production callers migrate from the
    /// former combined store. `MyAIMapApp` never constructs this initializer.
    @ObservationIgnored private let legacyStore: UniverseStore?
    /// Network assistant seam used only by DEBUG developer builds. Release
    /// construction receives an unavailable responder and always selects the
    /// local backend.
    @ObservationIgnored private let assistantResponder: any AssistantResponder

    /// Production initializer. Composition happens in `MyAIMapApp`; this model
    /// receives already-separated catalog, migration, and preferences owners.
    init(
        dependencies: CatalogRuntimeDependencies,
        assistantResponder: any AssistantResponder = AssistantResponderFactory.defaultResponder
    ) {
        self.catalogRepository = dependencies.repository
        self.preferences = dependencies.preferences
        self.migrationCoordinator = dependencies.migrationCoordinator
        self.legacyStore = nil
        self.assistantResponder = assistantResponder
        let savedPreferences = dependencies.preferences.load()
        let startup = dependencies.migrationCoordinator.prepareCatalog()
        switch startup {
        case .catalog(let document):
            self.customTools = document.tools
            self.customCategories = document.customCategories
            self.hiddenToolIDs = document.hiddenToolIDs
        case .recovery(let recovery):
            self.catalogRecovery = recovery
        }
        // Make persisted custom branches resolvable before any view reads the
        // seed's `category(_:)` (rail labels, logos, assistant grounding).
        UniverseSeed.registerCustomCategories(customCategories)
        self.hapticsEnabled = savedPreferences.hapticsEnabled
        self.hasSeenOnboarding = savedPreferences.hasSeenOnboarding
        self.subscription = savedPreferences.subscription
    }

    convenience init(assistantResponder: any AssistantResponder = AssistantResponderFactory.defaultResponder) {
        self.init(
            dependencies: CatalogRuntimeDependencies.production(),
            assistantResponder: assistantResponder
        )
    }

    /// Compatibility initializer for existing unit tests during the staged
    /// migration. It retains the old behavior but is never used by production
    /// composition; Batch 4 removes it after executed migration evidence.
    init(store: UniverseStore, assistantResponder: any AssistantResponder = AssistantResponderFactory.defaultResponder) {
        self.catalogRepository = nil
        self.preferences = nil
        self.migrationCoordinator = nil
        self.legacyStore = store
        self.assistantResponder = assistantResponder
        let saved = store.load()
        self.customTools = saved.tools
        self.customCategories = saved.customCategories
        UniverseSeed.registerCustomCategories(saved.customCategories)
        let sanitizedHidden = saved.hidden.subtracting([PlanetData.centralCoreToolID])
        self.hiddenToolIDs = sanitizedHidden
        self.hapticsEnabled = saved.hapticsEnabled
        self.hasSeenOnboarding = saved.hasSeenOnboarding
        self.subscription = saved.subscription
        if sanitizedHidden != saved.hidden {
            _ = commitCatalog(
                tools: customTools,
                customCategories: customCategories,
                hiddenToolIDs: hiddenToolIDs
            )
        }
    }

    /// Applies a verified backup only after an explicit action on the blocking
    /// recovery screen. It keeps navigation deterministic and never attempts to
    /// parse the corrupt primary in the view model.
    @discardableResult
    func restoreVerifiedCatalogBackup() -> Bool {
        guard catalogRecovery?.backupAvailable == true, let catalogRepository else { return false }
        do {
            let document = try catalogRepository.restoreVerifiedBackup()
            applyRecoveredCatalog(document)
            return true
        } catch {
            return false
        }
    }

    /// Replaces a recovery state with an explicitly confirmed empty catalog.
    /// A corrupt primary is never treated as a backup; its existing quarantine
    /// copy, when available, is left untouched for later export/support.
    @discardableResult
    func startNewUniverseAfterCatalogRecovery() -> Bool {
        guard catalogRecovery != nil, let catalogRepository else { return false }
        do {
            let document = CatalogDocument()
            try catalogRepository.replaceRecoveredCatalog(with: document)
            migrationCoordinator?.clearPendingMigrationAfterExplicitRecoveryReplacement()
            applyRecoveredCatalog(document)
            return true
        } catch {
            return false
        }
    }

    /// A failed normal save leaves in-memory state unchanged. When the existing
    /// primary is still valid, this lets a person continue with that last saved
    /// catalog instead of being trapped on recovery for a transient write error.
    @discardableResult
    func continueWithLastSavedCatalogAfterWriteFailure() -> Bool {
        guard catalogRecovery?.reason == .catalogCouldNotBeSaved,
              let catalogRepository,
              case .catalog(let document) = catalogRepository.load() else { return false }
        applyRecoveredCatalog(document)
        return true
    }

    /// Produces a validated native export document from the currently committed
    /// in-memory catalog. Recovery states cannot be exported as a normal
    /// catalog; their quarantine copy has its own explicit action.
    func catalogExportDocument() -> CatalogFileDocument? {
        guard catalogRecovery == nil else { return nil }
        return try? CatalogFileDocument(
            catalog: CatalogDocument(
                tools: customTools,
                customCategories: customCategories,
                hiddenToolIDs: hiddenToolIDs
            )
        )
    }

    /// Validates an external file without touching the live catalog. The
    /// Settings sheet asks for replacement confirmation only after this returns
    /// a document.
    func preparedCatalogImport(from data: Data) -> CatalogDocument? {
        guard catalogRecovery == nil else { return nil }
        return try? CatalogDocument.document(fromTransferData: data)
    }

    /// Replaces the live catalog only after the Settings confirmation. The
    /// repository's ordinary save protocol preserves a verified backup first.
    @discardableResult
    func replaceCatalogWithImportedDocument(_ document: CatalogDocument) -> Bool {
        guard commitCatalog(
            tools: document.tools,
            customCategories: document.customCategories,
            hiddenToolIDs: document.hiddenToolIDs
        ) else { return false }
        applyRecoveredCatalog(document)
        recordActivity(
            kind: .added,
            title: "Imported universe",
            detail: "Replaced local catalog",
            toolID: nil
        )
        return true
    }

    func recoveryCopyExportDocument() -> CatalogRecoveryCopyDocument? {
        guard catalogRecovery?.recoveryCopyAvailable == true,
              let catalogRepository,
              let data = try? catalogRepository.recoveryCopyData() else { return nil }
        return CatalogRecoveryCopyDocument(data: data)
    }

    private func applyRecoveredCatalog(_ document: CatalogDocument) {
        customTools = document.tools
        customCategories = document.customCategories
        hiddenToolIDs = document.hiddenToolIDs
        UniverseSeed.registerCustomCategories(document.customCategories)
        detailRoute = nil
        universeMode = .overview
        catalogRecovery = nil
    }

    /// Commits the complete next catalog before callers update observable map
    /// state. A persistence failure therefore cannot leave the UI showing a
    /// catalog that was never made durable.
    private func commitCatalog(
        tools: [Tool],
        customCategories: [ToolCategory],
        hiddenToolIDs: Set<String>
    ) -> Bool {
        if let legacyStore {
            legacyStore.save(
                tools: tools,
                customCategories: customCategories,
                hidden: hiddenToolIDs,
                hapticsEnabled: hapticsEnabled,
                hasSeenOnboarding: hasSeenOnboarding,
                subscription: subscription
            )
            return true
        }

        guard catalogRecovery == nil, let catalogRepository else { return false }
        do {
            try catalogRepository.save(
                CatalogDocument(
                    tools: tools,
                    customCategories: customCategories,
                    hiddenToolIDs: hiddenToolIDs
                )
            )
            return true
        } catch {
            catalogRecovery = CatalogRecovery(
                source: .primaryDocument,
                reason: .catalogCouldNotBeSaved,
                backupAvailable: false,
                recoveryCopyAvailable: false
            )
            return false
        }
    }

    private func persistPreferences() {
        if let legacyStore {
            legacyStore.save(
                tools: customTools,
                customCategories: customCategories,
                hidden: hiddenToolIDs,
                hapticsEnabled: hapticsEnabled,
                hasSeenOnboarding: hasSeenOnboarding,
                subscription: subscription
            )
            return
        }
        preferences?.save(
            UserDefaultsPreferences.Snapshot(
                hapticsEnabled: hapticsEnabled,
                hasSeenOnboarding: hasSeenOnboarding,
                subscription: subscription
            )
        )
    }

    /// Marks first-run onboarding complete and persists it. Idempotent: any of
    /// the overlay's actions, Skip, or a scrim tap may call it.
    func markOnboardingSeen() {
        guard !hasSeenOnboarding else { return }
        hasSeenOnboarding = true
        persistPreferences()
    }

    /// UI-test harness reset for the first-run overlay. Kept explicit so the
    /// default UI-test flags can still suppress onboarding, while
    /// `-uitestOnboarding` can exercise the real first-run surface.
    func resetOnboardingForUITests() {
        guard hasSeenOnboarding else { return }
        hasSeenOnboarding = false
        persistPreferences()
    }

    // MARK: - Derived state

    /// Read-only projection of `universeMode` for surfaces that think in terms
    /// of "current category + current tool" (rail, chips, detail card). When no
    /// tool is explicitly selected (overview / branchFocus), the selected tool
    /// defaults to the focused category's first tool — preserving the Phase 1
    /// "always-a-tool" behaviour the detail card relies on.
    var selection: UniverseSelection {
        let category = universeMode.focusedCategory
        let toolID = universeMode.selectedToolID
            ?? tools(in: category).first?.id
            ?? tools(in: .core).first?.id
            ?? PlanetData.centralCoreToolID
        return UniverseSelection(
            activeCategory: category,
            selectedToolID: toolID
        )
    }

    /// The user's universe is exactly the tools they have added. The seed is
    /// sample data (`loadSampleUniverse()`), never a silent default.
    var allTools: [Tool] {
        customTools
    }

    /// Every category the renderer may need to lay out: the seed branches plus
    /// any user/AI-created custom branches. `PlanetData.makePlanets` filters
    /// this down to categories that actually hold a visible tool, so passing the
    /// full set is safe — empty branches simply don't light up a planet.
    var allCategories: [ToolCategory] {
        UniverseSeed.categories + customCategories
    }

    /// True before the user has added (or sampled) anything — drives the
    /// empty-state onboarding.
    var isUniverseEmpty: Bool {
        visibleAllTools.isEmpty
    }

    var visibleAllTools: [Tool] {
        allTools.filter { !hiddenToolIDs.contains($0.id) }
    }

    var removedTools: [Tool] {
        allTools.filter { hiddenToolIDs.contains($0.id) }
    }

    var selectedCategoryModel: ToolCategory {
        UniverseSeed.category(selection.activeCategory)
    }

    /// Tools for the active category, falling back to the core slice so
    /// the rail never renders empty (Phase 1 parity).
    var visibleTools: [Tool] {
        let activeTools = tools(in: selection.activeCategory)
        return activeTools.isEmpty ? tools(in: .core) : activeTools
    }

    /// The currently selected tool, or `nil` when the universe is empty (no
    /// tool to select yet).
    var selectedTool: Tool? {
        visibleAllTools.first { $0.id == selection.selectedToolID }
            ?? visibleTools.first
            ?? visibleAllTools.first
    }

    /// Ranked matches via `SearchCore` (name-prefix > name > summary >
    /// category short-name, capped at `SearchCore.maxResults`).
    /// Whitespace-only queries return nothing so the search dock can
    /// treat "no text" and "no results" identically.
    var searchResults: [Tool] {
        SearchCore.results(
            for: searchQuery,
            in: visibleAllTools,
            categoryName: { UniverseSeed.category($0).shortName },
            extraText: { ToolKnowledgeBook.knowledge(for: $0).searchableText }
        )
    }

    var assistantPreviewResults: [Tool] {
        SearchCore.results(
            for: assistantQuery,
            in: visibleAllTools,
            categoryName: { UniverseSeed.category($0).shortName },
            extraText: { ToolKnowledgeBook.knowledge(for: $0).searchableText }
        )
    }

    // MARK: - Intents

    /// Populates the empty universe with the bundled sample (the founder's
    /// seed), skipping anything already present. Used by the empty-state
    /// "load a sample universe" affordance.
    @discardableResult
    func loadSampleUniverse() -> Bool {
        let existingIDs = Set(customTools.map(\.id))
        let sampleIDs = Set(UniverseSeed.tools.map(\.id))
        let newTools = UniverseSeed.tools.filter { !existingIDs.contains($0.id) }
        // Loading the sample also un-hides any sample tool the user previously
        // deleted (otherwise a re-load silently leaves it hidden — F1).
        let willUnhide = !hiddenToolIDs.isDisjoint(with: sampleIDs)
        guard !newTools.isEmpty || willUnhide else { return false }
        let nextTools = customTools + newTools
        let nextHiddenToolIDs = hiddenToolIDs.subtracting(sampleIDs)
        guard commitCatalog(
            tools: nextTools,
            customCategories: customCategories,
            hiddenToolIDs: nextHiddenToolIDs
        ) else { return false }
        customTools = nextTools
        hiddenToolIDs = nextHiddenToolIDs
        UniverseSeed.registerCustomCategories(customCategories)
        recordActivity(
            kind: .added,
            title: "Loaded sample universe",
            detail: newTools.isEmpty ? "Restored sample tools" : "\(newTools.count) tools added",
            toolID: nil
        )
        return true
    }

    /// Whether anything is persisted (added or hidden). Distinct from
    /// `isUniverseEmpty`: hiding every tool makes the map empty while data
    /// still sits in storage, so Reset must gate on this, not emptiness (F2).
    var hasStoredData: Bool {
        !customTools.isEmpty || !customCategories.isEmpty || !hiddenToolIDs.isEmpty
    }

    /// Wipes the user's universe back to empty (custom tools + hidden ids).
    func resetUniverse() {
        guard commitCatalog(tools: [], customCategories: [], hiddenToolIDs: []) else { return }
        customTools.removeAll()
        customCategories.removeAll()
        hiddenToolIDs.removeAll()
        UniverseSeed.registerCustomCategories([])
        detailRoute = nil
        universeMode = .overview
        recordActivity(
            kind: .removed,
            title: "Reset universe",
            detail: "Cleared all tools",
            toolID: nil
        )
    }

    func selectCategory(_ id: ToolCategoryId) {
        // Re-tapping the active category is a no-op so it never resets the
        // current tool selection (Phase 1 parity). The "first tool of the
        // category" default is applied by the `selection` projection.
        guard universeMode.focusedCategory != id else { return }
        universeMode = id == .core ? .overview : .branchFocus(id)
    }

    func selectTool(_ id: String) {
        guard let tool = visibleAllTools.first(where: { $0.id == id }) else { return }
        universeMode = .toolSelected(tool.category, tool.id)
    }

    /// Opens the compact detail route for a visible tool. A detail route always
    /// restores to the concrete selected-tool mode so the map returns to the
    /// exact node the user was reading.
    func requestDetail(for toolID: String) {
        guard let tool = visibleAllTools.first(where: { $0.id == toolID }) else { return }
        let returnMode: UniverseMode
        if case .toolSelected(_, let selectedToolID) = universeMode, selectedToolID == toolID {
            returnMode = universeMode
        } else {
            returnMode = .toolSelected(tool.category, tool.id)
        }

        detailRoute = DetailRoute(toolID: tool.id, returnMode: returnMode)
        universeMode = .detail(tool.category, tool.id)
    }

    /// Restores the exact navigation state captured when the compact detail
    /// route opened. It is deliberately idempotent because SwiftUI calls this
    /// path for both a binding-driven system dismissal and `onDismiss`.
    func dismissDetail() {
        guard let route = detailRoute else { return }
        universeMode = route.returnMode
        detailRoute = nil
    }

    /// Changes the visible detail content without adding a second presentation
    /// flag. Related-tool navigation preserves the sheet presentation identity
    /// while replacing its typed content route.
    func replaceDetailTool(with toolID: String) {
        guard let existingRoute = detailRoute else {
            requestDetail(for: toolID)
            return
        }
        guard let tool = visibleAllTools.first(where: { $0.id == toolID }) else { return }

        detailRoute = DetailRoute(
            id: existingRoute.id,
            toolID: tool.id,
            returnMode: .toolSelected(tool.category, tool.id)
        )
        universeMode = .detail(tool.category, tool.id)
    }

    /// Selects a tool from any surface that can name a tool id: node tap,
    /// search result, or relation row. Returns false when the id is not
    /// in the seed so callers can skip haptics for stale references.
    @discardableResult
    func focusTool(_ id: String) -> Bool {
        guard let tool = visibleAllTools.first(where: { $0.id == id }) else { return false }
        universeMode = .toolSelected(tool.category, tool.id)
        clarityMode = .focus
        recordActivity(
            kind: .focused,
            title: "Opened \(tool.name)",
            detail: UniverseSeed.category(tool.category).name,
            toolID: tool.id
        )
        return true
    }

    /// Requests a tool's detail route before `RootShell` returns to the map.
    /// The compact map host binds that route to its one system sheet.
    @discardableResult
    func requestToolDetail(_ id: String) -> Bool {
        guard visibleAllTools.contains(where: { $0.id == id }) else { return false }
        requestDetail(for: id)
        return detailRoute?.toolID == id
    }

    /// Enter-to-focus parity with the web build ([C3], `focusTool` in
    /// AIToolUniverseMap.tsx): selects the first search match, jumps to
    /// its category, snaps clarity to focus, and clears the query.
    /// Returns whether a match was focused.
    @discardableResult
    func focusFirstSearchMatch() -> Bool {
        guard let match = searchResults.first else { return false }
        universeMode = .toolSelected(match.category, match.id)
        clarityMode = .focus
        searchQuery = ""
        return true
    }

    func askAssistant(attachmentOnly: Bool = false) {
        let query = assistantQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }

        assistantMessages.append(AssistantMessage(role: .user, text: query))

        // The assistant is a local tool-matcher; it cannot read attachments.
        // For an attachment-only message, answer honestly instead of matching
        // tools against the literal "attached photo/file" text (U1).
        if attachmentOnly {
            assistantMessages.append(
                AssistantMessage(
                    role: .assistant,
                    text: "I can't read attachments yet. Tell me what you want to build, compare, or add — or paste the tool's website link."
                )
            )
            assistantQuery = ""
            recordActivity(kind: .asked, title: "Asked AI", detail: query, toolID: nil)
            return
        }

        // Placeholder usage accounting: each real Ask-AI send decrements the
        // remaining count so the Settings number visibly moves (no real quota).
        consumeAIRequest()

        // Local rule-based reply is always computed first: it stays the default
        // offline behavior and provides the chip match-IDs the UI relies on.
        let local = UniverseAssistantCore.reply(
            for: query,
            tools: visibleAllTools,
            categoryName: { UniverseSeed.category($0).shortName },
            knowledge: { ToolKnowledgeBook.knowledge(for: $0) },
            recentActivity: activityHistory
        )

        // Route through the AssistantBackend seam, never DeepSeek directly. Only
        // the debug/developer DeepSeek path calls out; on missing config OR any
        // error we fall back to the local reply below. Release builds and normal
        // users always resolve to `.local`.
        if activeBackend == .debugDeepSeek {
            let tools = visibleAllTools
            let systemPrompt = Self.deepSeekSystemPrompt(for: tools)
            let responder = assistantResponder
            Task { [weak self] in
                do {
                    let text = try await responder.reply(to: query, systemPrompt: systemPrompt, apiKey: nil)
                    await self?.appendAssistantReply(text: text, query: query, fallback: local)
                } catch {
                    await self?.appendAssistantReply(text: nil, query: query, fallback: local)
                }
            }
            assistantQuery = ""
            return
        }

        // Synchronous local path: nothing can be typed between here and the
        // append, so clearing the composer now is safe (mirrors the up-front
        // clear on the async DeepSeek branch above).
        assistantQuery = ""
        appendLocalReply(local, query: query)
    }

    /// The backend the assistant will use, resolved through the seam. Normal
    /// builds/users get `.local`; `.debugDeepSeek` only when developer mode is
    /// on AND a key is stored (see `AssistantBackend`).
    var activeBackend: AssistantBackend {
        #if DEBUG
        AssistantBackend.resolve(
            developerModeEnabled: DeveloperMode.isEnabled,
            hasDeepSeekKey: KeychainStore.hasValue(account: KeychainStore.deepSeekAPIKeyAccount)
        )
        #else
        .local
        #endif
    }

    /// Increments the local placeholder usage counter and persists it.
    private func consumeAIRequest() {
        subscription.consumeRequest()
        persistPreferences()
    }

    private func appendAssistantReply(text: String?, query: String, fallback: AssistantReply) {
        guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            // Missing-key / network / decode failure → local rule-based reply.
            appendLocalReply(fallback, query: query)
            return
        }
        // DeepSeek answers the text; the local matcher still supplies chip
        // match-IDs and missing-tool suggestions so the UI keeps working.
        assistantMessages.append(
            AssistantMessage(
                role: .assistant,
                text: text,
                matchIDs: fallback.matchIDs,
                missingToolSuggestions: fallback.missingToolSuggestions
            )
        )
        recordActivity(kind: .asked, title: "Asked AI", detail: query, toolID: fallback.matchIDs.first)
    }

    /// Appends a local rule-based assistant reply. Deliberately does NOT touch
    /// `assistantQuery`: the composer reset belongs to the SYNCHRONOUS send site
    /// (see `askAssistant`). This method is also reached from the ASYNC
    /// DeepSeek-failure fallback, where clearing here would wipe a query the user
    /// typed while the round-trip was in flight.
    private func appendLocalReply(_ reply: AssistantReply, query: String) {
        assistantMessages.append(
            AssistantMessage(
                role: .assistant,
                text: reply.text,
                matchIDs: reply.matchIDs,
                missingToolSuggestions: reply.missingToolSuggestions
            )
        )
        recordActivity(kind: .asked, title: "Asked AI", detail: query, toolID: reply.matchIDs.first)
    }

    /// Grounds the DeepSeek prompt in the user's current catalog so it answers
    /// about tools that actually exist and keeps the "never fabricate tools"
    /// principle: when a service is missing, it asks for the website instead of
    /// inventing facts.
    private static func deepSeekSystemPrompt(for tools: [Tool]) -> String {
        let catalog = tools
            .map { "- \($0.name) (\(UniverseSeed.category($0.category).shortName))" }
            .joined(separator: "\n")
        let list = catalog.isEmpty ? "(the user's universe is currently empty)" : catalog
        return """
        You are the in-app assistant for "My AI Map", a universe of AI tools the user has added.
        Only recommend tools from the catalog below. Never invent tools, pricing, or features.
        If the user asks about a tool not in the catalog, say it isn't in their universe yet and ask for its website URL.
        Be concise and practical.

        Catalog:
        \(list)
        """
    }

    @discardableResult
    func deleteTool(_ id: String) -> Bool {
        guard let tool = visibleAllTools.first(where: { $0.id == id }), tool.category != .core else { return false }
        let nextHiddenToolIDs = hiddenToolIDs.union([id])
        guard commitCatalog(
            tools: customTools,
            customCategories: customCategories,
            hiddenToolIDs: nextHiddenToolIDs
        ) else { return false }
        hiddenToolIDs = nextHiddenToolIDs
        if detailRoute?.toolID == id {
            detailRoute = nil
        }
        recordActivity(
            kind: .removed,
            title: "Removed \(tool.name)",
            detail: "Hidden from map and assistant results",
            toolID: id
        )

        // If the deleted tool was the selected one, drop back to the focused
        // category (the projection re-picks that category's first tool).
        if universeMode.selectedToolID == id {
            let category = universeMode.focusedCategory
            universeMode = category == .core ? .overview : .branchFocus(category)
        }
        return true
    }

    @discardableResult
    func restoreTool(_ id: String) -> Bool {
        guard let tool = allTools.first(where: { $0.id == id }), hiddenToolIDs.contains(id) else { return false }
        let nextHiddenToolIDs = hiddenToolIDs.subtracting([id])
        guard commitCatalog(
            tools: customTools,
            customCategories: customCategories,
            hiddenToolIDs: nextHiddenToolIDs
        ) else { return false }
        hiddenToolIDs = nextHiddenToolIDs
        recordActivity(
            kind: .restored,
            title: "Restored \(tool.name)",
            detail: UniverseSeed.category(tool.category).name,
            toolID: id
        )
        return true
    }

    /// Palette for custom branches: hues distinct from the seed branch colors so
    /// a new branch reads as its own orbit, cycled by creation order.
    private static let customBranchPalette: [(color: ColorHex, glow: ColorHex)] = [
        (ColorHex(stringLiteral: "#F472B6"), ColorHex(stringLiteral: "#FBCFE8")),
        (ColorHex(stringLiteral: "#34D399"), ColorHex(stringLiteral: "#A7F3D0")),
        (ColorHex(stringLiteral: "#FBBF24"), ColorHex(stringLiteral: "#FDE68A")),
        (ColorHex(stringLiteral: "#A78BFA"), ColorHex(stringLiteral: "#DDD6FE")),
        (ColorHex(stringLiteral: "#22D3EE"), ColorHex(stringLiteral: "#A5F3FC")),
        (ColorHex(stringLiteral: "#FB7185"), ColorHex(stringLiteral: "#FECDD3")),
    ]

    /// Creates a new user/AI branch (blueprint §8). Builds a `ToolCategory` from
    /// a slug of `name`, picks a palette color not used by the seed, and places
    /// it at the next free orbital slot. Idempotent on slug: an existing branch
    /// (seed or custom) with the same id is returned instead of duplicated.
    /// Registers + persists so the branch is immediately resolvable, rendered,
    /// and search/assistant-aware.
    @discardableResult
    func createBranch(name: String) -> ToolCategoryId {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseSlug = slug(cleanName)
        let id = ToolCategoryId(rawValue: baseSlug.isEmpty ? uniqueCategorySlug(base: "branch") : uniqueCategorySlug(base: baseSlug))

        let display = cleanName.isEmpty ? id.rawValue.capitalized : cleanName
        let palette = Self.customBranchPalette[customCategories.count % Self.customBranchPalette.count]
        // Next free orbital slot: seed branches occupy 0..<8 conceptually, so
        // fan custom branches out beyond them in even steps.
        let branchCount = UniverseSeed.categories.filter { $0.id != .core }.count + customCategories.count
        let angle = Float((branchCount * 47) % 360)

        let category = ToolCategory(
            id: id,
            name: display,
            shortName: display,
            description: "Custom branch added from intake.",
            color: palette.color,
            glow: palette.glow,
            angle: angle
        )
        let nextCategories = customCategories + [category]
        guard commitCatalog(
            tools: customTools,
            customCategories: nextCategories,
            hiddenToolIDs: hiddenToolIDs
        ) else { return id }
        customCategories = nextCategories
        UniverseSeed.registerCustomCategories(nextCategories)
        recordActivity(
            kind: .added,
            title: "Created \(display) branch",
            detail: "New universe branch",
            toolID: nil
        )
        return id
    }

    private func uniqueCategorySlug(base: String) -> String {
        var candidate = base
        var suffix = 2
        let existing = Set(allCategories.map { $0.id.rawValue })
        while existing.contains(candidate) {
            candidate = "\(base)-\(suffix)"
            suffix += 1
        }
        return candidate
    }

    @discardableResult
    func addCustomTool(name: String, urlString: String, category: ToolCategoryId) -> Bool {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty, category != .core else { return false }

        let url = normalizedURL(from: urlString)
        let sourceHost = url.flatMap { normalizedSourceHost(from: $0) }
        if let existingTool = existingToolMatching(name: cleanName, sourceHost: sourceHost) {
            let wasHidden = hiddenToolIDs.contains(existingTool.id)
            if wasHidden {
                let nextHiddenToolIDs = hiddenToolIDs.subtracting([existingTool.id])
                guard commitCatalog(
                    tools: customTools,
                    customCategories: customCategories,
                    hiddenToolIDs: nextHiddenToolIDs
                ) else { return false }
                hiddenToolIDs = nextHiddenToolIDs
                recordActivity(
                    kind: .restored,
                    title: "Restored \(existingTool.name)",
                    detail: UniverseSeed.category(existingTool.category).name,
                    toolID: existingTool.id
                )
            }
            _ = focusTool(existingTool.id)
            return true
        }

        let id = uniqueID(base: slug(cleanName))
        let categoryTools = allTools.filter { $0.category == category }
        let categoryAngle = UniverseSeed.category(category).angle
        let relationIds = suggestedRelations(for: cleanName, category: category)
        let summary = if let sourceHost {
            "User-added service. Source domain: \(sourceHost). Claims stay cautious until website-backed enrichment."
        } else {
            "User-added service. Website not provided; claims remain unverified."
        }
        let classificationReason = if let sourceHost {
            "Added from account intake with source domain \(sourceHost). Needs enrichment before precise claims."
        } else {
            "Added from account intake without a website. Claims remain unverified until a source is provided."
        }

        let tool = Tool(
            id: id,
            name: cleanName,
            category: category,
            summary: summary,
            stage: .research,
            orbit: categoryTools.count.isMultiple(of: 2) ? .middle : .inner,
            angle: categoryAngle,
            url: url,
            logoDomain: sourceHost,
            relationIds: relationIds,
            classification: Tool.Classification(
                confidence: url == nil ? 0.48 : 0.74,
                matchedKeywords: [category.rawValue],
                reason: classificationReason
            )
        )
        let nextTools = customTools + [tool]
        guard commitCatalog(
            tools: nextTools,
            customCategories: customCategories,
            hiddenToolIDs: hiddenToolIDs
        ) else { return false }
        customTools = nextTools
        recordActivity(
            kind: .added,
            title: "Added \(tool.name)",
            detail: UniverseSeed.category(category).name,
            toolID: tool.id
        )
        _ = focusTool(tool.id)
        return true
    }

    private func tools(in category: ToolCategoryId) -> [Tool] {
        visibleAllTools.filter { $0.category == category }
    }

    private func recordActivity(kind: UniverseActivityKind, title: String, detail: String, toolID: String?) {
        activityHistory.insert(
            UniverseActivity(kind: kind, title: title, detail: detail, toolID: toolID),
            at: 0
        )
        if activityHistory.count > 40 {
            activityHistory.removeLast(activityHistory.count - 40)
        }
    }

    private func normalizedURL(from value: String) -> URL? {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return nil }
        let lower = clean.lowercased()
        guard !lower.contains("://") || lower.hasPrefix("http://") || lower.hasPrefix("https://") else { return nil }

        let candidate: String
        if lower.hasPrefix("http://") {
            candidate = "https://\(clean.dropFirst("http://".count))"
        } else if lower.hasPrefix("https://") {
            candidate = clean
        } else {
            candidate = "https://\(clean)"
        }

        guard let url = URL(string: candidate),
              let scheme = url.scheme?.lowercased(),
              scheme == "https",
              url.host() != nil else { return nil }
        return url
    }

    private func existingToolMatching(name: String, sourceHost: String?) -> Tool? {
        let nameSlug = slug(name)
        if let sourceHost,
           let hostMatch = allTools.first(where: { $0.logoDomain == sourceHost && slug($0.name) == nameSlug }) {
            return hostMatch
        }

        return allTools.first { tool in
            tool.id == nameSlug || slug(tool.name) == nameSlug
        }
    }

    private func normalizedSourceHost(from url: URL) -> String? {
        guard var host = url.host()?.lowercased(), !host.isEmpty else { return nil }
        if host.hasPrefix("www.") {
            host.removeFirst(4)
        }
        return host
    }

    private func uniqueID(base: String) -> String {
        let safeBase = base.isEmpty ? "tool" : base
        var candidate = safeBase
        var suffix = 2
        let ids = Set(allTools.map(\.id))
        while ids.contains(candidate) {
            candidate = "\(safeBase)-\(suffix)"
            suffix += 1
        }
        return candidate
    }

    private func slug(_ value: String) -> String {
        let folded = value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        let allowed = CharacterSet.alphanumerics
        let scalars = folded.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" }
        return String(scalars)
            .split(separator: "-")
            .joined(separator: "-")
            .lowercased()
    }

    private func suggestedRelations(for name: String, category: ToolCategoryId) -> [String] {
        let folded = name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        if folded.contains("chrome") {
            return visibleAllTools.filter { $0.name.localizedCaseInsensitiveContains("browser") }.map(\.id)
        }
        return visibleAllTools
            .filter { $0.category == category && $0.id != "founder-os" }
            .prefix(3)
            .map(\.id)
    }
}
