import Foundation
import Observation

/// Single source of truth for universe UI state, per the Phase 2
/// decision log: `@Observable` class injected via environment — not
/// `@EnvironmentObject`. Owns selection, hover, active category,
/// clarity mode, and search query. Never touches the RealityKit graph;
/// `CameraController` owns the camera entity.
@MainActor
@Observable
final class UniverseViewModel {
    /// SINGLE SOURCE OF TRUTH for navigation (see docs/UI_STATE_MACHINE.md).
    /// `selectedCategory` and `selectedTool` are projected from this — nothing
    /// else stores them, so map / chips / rail / card can never desync.
    var universeMode: UniverseMode = .overview

    /// Hover is independent of the navigation mode.
    private(set) var hoveredToolID: String?
    // Web parity: AIToolUniverseMap.tsx:150 initialises mapClarity to 'focus'.
    var clarityMode: ClarityMode = .focus
    var searchQuery: String = ""
    var assistantQuery: String = ""
    var assistantMessages: [AssistantMessage] = []
    var renderMode: UniverseRenderMode = .graph2D {
        didSet {
            guard oldValue != renderMode else { return }
            persist()
        }
    }
    var visualizationStyle: VisualizationStyle = .orbitalGlass
    var appLanguage: AppLanguage = .system
    var hapticsEnabled: Bool = true {
        didSet {
            guard oldValue != hapticsEnabled else { return }
            persist()
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

    @ObservationIgnored private let store: UniverseStore

    /// Loads any previously-built universe from local storage. A brand-new user
    /// has none, so they start with an empty universe (see `UniverseStore`).
    init(store: UniverseStore = .standard) {
        self.store = store
        let saved = store.load()
        self.customTools = saved.tools
        self.customCategories = saved.customCategories
        // Make persisted custom branches resolvable before any view reads the
        // seed's `category(_:)` (rail labels, logos, assistant grounding).
        UniverseSeed.registerCustomCategories(saved.customCategories)
        // Defensive: the core tool (founder-os) must never be hidden. The
        // selection projection falls back to it, so a stale/corrupt persisted
        // hidden set containing it would strand selection (selectedTool == nil).
        // Mirror the deleteTool `.core` guard at load time and re-persist clean.
        let sanitizedHidden = saved.hidden.subtracting([PlanetData.centralCoreToolID])
        self.hiddenToolIDs = sanitizedHidden
        self.renderMode = saved.renderMode
        self.hapticsEnabled = saved.hapticsEnabled
        self.hasSeenOnboarding = saved.hasSeenOnboarding
        self.subscription = saved.subscription
        if sanitizedHidden != saved.hidden {
            persist()
        }
    }

    private func persist() {
        // Keep the seed registry in lockstep with the persisted set so any
        // mutation (createBranch, reset) immediately reflects in resolution.
        UniverseSeed.registerCustomCategories(customCategories)
        store.save(
            tools: customTools,
            customCategories: customCategories,
            hidden: hiddenToolIDs,
            renderMode: renderMode,
            hapticsEnabled: hapticsEnabled,
            hasSeenOnboarding: hasSeenOnboarding,
            subscription: subscription
        )
    }

    /// Marks first-run onboarding complete and persists it. Idempotent: any of
    /// the overlay's actions, Skip, or a scrim tap may call it.
    func markOnboardingSeen() {
        guard !hasSeenOnboarding else { return }
        hasSeenOnboarding = true
        persist()
    }

    /// UI-test harness reset for the first-run overlay. Kept explicit so the
    /// default UI-test flags can still suppress onboarding, while
    /// `-uitestOnboarding` can exercise the real first-run surface.
    func resetOnboardingForUITests() {
        guard hasSeenOnboarding else { return }
        hasSeenOnboarding = false
        persist()
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
            selectedToolID: toolID,
            hoveredToolID: hoveredToolID
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
        customTools.append(contentsOf: newTools)
        hiddenToolIDs.subtract(sampleIDs)
        persist()
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
        !customTools.isEmpty || !hiddenToolIDs.isEmpty
    }

    /// Wipes the user's universe back to empty (custom tools + hidden ids).
    func resetUniverse() {
        customTools.removeAll()
        customCategories.removeAll()
        hiddenToolIDs.removeAll()
        universeMode = .overview
        persist()
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

    /// Set by the chat surface to request a tool's full detail sheet. The chat
    /// and map are mutually-exclusive surfaces, so the chat can't present the
    /// sheet itself — `UniverseMapView` consumes this on appear/change and clears
    /// it. §6.3: existing-tool chips open detail, not just a map focus.
    var pendingDetailToolID: String?

    /// Focus a tool and request its detail sheet (chat "open detail" chips).
    @discardableResult
    func requestToolDetail(_ id: String) -> Bool {
        guard focusTool(id) else { return false }
        pendingDetailToolID = id
        return true
    }

    func setHover(_ id: String?) {
        hoveredToolID = id
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
            Task { [weak self] in
                do {
                    let text = try await DeepSeekClient().reply(to: query, systemPrompt: systemPrompt)
                    await self?.appendAssistantReply(text: text, query: query, fallback: local)
                } catch {
                    await self?.appendAssistantReply(text: nil, query: query, fallback: local)
                }
            }
            assistantQuery = ""
            return
        }

        appendLocalReply(local, query: query)
    }

    /// The backend the assistant will use, resolved through the seam. Normal
    /// builds/users get `.local`; `.debugDeepSeek` only when developer mode is
    /// on AND a key is stored (see `AssistantBackend`).
    var activeBackend: AssistantBackend {
        AssistantBackend.resolve(
            developerModeEnabled: DeveloperMode.isEnabled,
            hasDeepSeekKey: KeychainStore.hasValue(account: KeychainStore.deepSeekAPIKeyAccount)
        )
    }

    /// Increments the local placeholder usage counter and persists it.
    private func consumeAIRequest() {
        subscription.consumeRequest()
        persist()
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
        assistantQuery = ""
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
        hiddenToolIDs.insert(id)
        persist()
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
        guard let tool = allTools.first(where: { $0.id == id }), hiddenToolIDs.remove(id) != nil else { return false }
        persist()
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
        customCategories.append(category)
        persist()
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
            let wasHidden = hiddenToolIDs.remove(existingTool.id) != nil
            if wasHidden {
                persist()
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
        customTools.append(tool)
        persist()
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
           let hostMatch = allTools.first(where: { $0.logoDomain == sourceHost }) {
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
