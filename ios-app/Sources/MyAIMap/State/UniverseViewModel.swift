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
    private(set) var activityHistory: [UniverseActivity] = []
    private(set) var hiddenToolIDs: Set<String> = []
    private(set) var customTools: [Tool] = []

    @ObservationIgnored private let store: UniverseStore

    /// Loads any previously-built universe from local storage. A brand-new user
    /// has none, so they start with an empty universe (see `UniverseStore`).
    init(store: UniverseStore = .standard) {
        self.store = store
        let saved = store.load()
        self.customTools = saved.tools
        // Defensive: the core tool (founder-os) must never be hidden. The
        // selection projection falls back to it, so a stale/corrupt persisted
        // hidden set containing it would strand selection (selectedTool == nil).
        // Mirror the deleteTool `.core` guard at load time and re-persist clean.
        let sanitizedHidden = saved.hidden.subtracting([PlanetData.centralCoreToolID])
        self.hiddenToolIDs = sanitizedHidden
        self.renderMode = saved.renderMode
        self.hapticsEnabled = saved.hapticsEnabled
        if sanitizedHidden != saved.hidden {
            persist()
        }
    }

    private func persist() {
        store.save(
            tools: customTools,
            hidden: hiddenToolIDs,
            renderMode: renderMode,
            hapticsEnabled: hapticsEnabled
        )
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

    func askAssistant() {
        let query = assistantQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }

        assistantMessages.append(AssistantMessage(role: .user, text: query))
        let reply = UniverseAssistantCore.reply(
            for: query,
            tools: visibleAllTools,
            categoryName: { UniverseSeed.category($0).shortName },
            knowledge: { ToolKnowledgeBook.knowledge(for: $0) },
            recentActivity: activityHistory
        )
        assistantMessages.append(
            AssistantMessage(
                role: .assistant,
                text: reply.text,
                matchIDs: reply.matchIDs,
                missingToolSuggestions: reply.missingToolSuggestions
            )
        )
        assistantQuery = ""
        recordActivity(
            kind: .asked,
            title: "Asked AI",
            detail: query,
            toolID: reply.matchIDs.first
        )
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
