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
    private(set) var selection = UniverseSelection()
    // Web parity: AIToolUniverseMap.tsx:150 initialises mapClarity to 'focus'.
    var clarityMode: ClarityMode = .focus
    var searchQuery: String = ""
    var assistantQuery: String = ""
    var assistantMessages: [AssistantMessage] = []
    var visualizationStyle: VisualizationStyle = .orbitalGlass
    var appLanguage: AppLanguage = .system
    var hapticsEnabled: Bool = true
    private(set) var activityHistory: [UniverseActivity] = []
    private(set) var hiddenToolIDs: Set<String> = []
    private(set) var customTools: [Tool] = []

    // MARK: - Derived state

    var allTools: [Tool] {
        UniverseSeed.tools + customTools
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

    var selectedTool: Tool {
        visibleAllTools.first { $0.id == selection.selectedToolID }
            ?? visibleTools.first
            ?? visibleAllTools.first
            ?? UniverseSeed.tools[0]
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

    func selectCategory(_ id: ToolCategoryId) {
        // Phase 1 parity: .onChange(of:) was equality-gated, so re-tapping
        // the active category chip must not reset the tool selection.
        guard selection.activeCategory != id else { return }
        selection.activeCategory = id
        selection.selectedToolID = tools(in: id).first?.id ?? tools(in: .core).first?.id ?? "founder-os"
    }

    func selectTool(_ id: String) {
        guard let tool = visibleAllTools.first(where: { $0.id == id }) else { return }
        selection.activeCategory = tool.category
        selection.selectedToolID = tool.id
    }

    /// Selects a tool from any surface that can name a tool id: node tap,
    /// search result, or relation row. Returns false when the id is not
    /// in the seed so callers can skip haptics for stale references.
    @discardableResult
    func focusTool(_ id: String) -> Bool {
        guard let tool = visibleAllTools.first(where: { $0.id == id }) else { return false }
        selection.activeCategory = tool.category
        selection.selectedToolID = tool.id
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
        selection.hoveredToolID = id
    }

    /// Enter-to-focus parity with the web build ([C3], `focusTool` in
    /// AIToolUniverseMap.tsx): selects the first search match, jumps to
    /// its category, snaps clarity to focus, and clears the query.
    /// Returns whether a match was focused.
    @discardableResult
    func focusFirstSearchMatch() -> Bool {
        guard let match = searchResults.first else { return false }
        selectCategory(match.category)
        selection.selectedToolID = match.id
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
            knowledge: { ToolKnowledgeBook.knowledge(for: $0) }
        )
        assistantMessages.append(AssistantMessage(role: .assistant, text: reply.text, matchIDs: reply.matchIDs))
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
        recordActivity(
            kind: .removed,
            title: "Removed \(tool.name)",
            detail: "Hidden from map and assistant results",
            toolID: id
        )

        if selection.selectedToolID == id {
            selection.selectedToolID = tools(in: selection.activeCategory).first?.id
                ?? tools(in: .core).first?.id
                ?? "founder-os"
            selection.activeCategory = selectedTool.category
        }
        return true
    }

    @discardableResult
    func restoreTool(_ id: String) -> Bool {
        guard let tool = allTools.first(where: { $0.id == id }), hiddenToolIDs.remove(id) != nil else { return false }
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
        let id = uniqueID(base: slug(cleanName))
        let categoryTools = allTools.filter { $0.category == category }
        let categoryAngle = UniverseSeed.category(category).angle
        let relationIds = suggestedRelations(for: cleanName, category: category)

        let tool = Tool(
            id: id,
            name: cleanName,
            category: category,
            summary: "User-added service. Website verified by URL before deep claims are made.",
            stage: .research,
            orbit: categoryTools.count.isMultiple(of: 2) ? .middle : .inner,
            angle: categoryAngle,
            url: url,
            logoDomain: url?.host,
            relationIds: relationIds,
            classification: Tool.Classification(
                confidence: url == nil ? 0.48 : 0.74,
                matchedKeywords: [category.rawValue],
                reason: "Added from account intake. Needs website-backed enrichment before precise claims."
            )
        )
        customTools.append(tool)
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
        let candidate = clean.hasPrefix("http://") || clean.hasPrefix("https://") ? clean : "https://\(clean)"
        guard let url = URL(string: candidate),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else { return nil }
        return url
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
