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

    /// Tool add/delete history (P4). Pure `ToolHistory` value type; side
    /// effects (persistence) live in `historyStore`, mirroring how
    /// `SearchCore`/`UniverseSelection` keep logic out of the side-effecting
    /// shell. Loaded on init, saved on every mutation.
    private(set) var history: ToolHistory
    @ObservationIgnored private let historyStore: HistoryStore?

    /// Tests pass `historyStore: nil` to skip persistence; production callers
    /// get the default `UserDefaults`-backed store. Defaulting both params
    /// preserves the zero-arg `UniverseViewModel()` callers already use.
    init(history: ToolHistory? = nil, historyStore: HistoryStore? = HistoryStore()) {
        self.historyStore = historyStore
        self.history = history ?? historyStore?.load() ?? ToolHistory()
    }

    /// Memoised inferred relationship edges per tool id (P9). Computed once
    /// per id via `RelationshipIntelligence.infer` over the seed universe and
    /// cached, so neither the detail sheet nor the link-drawing pass triggers
    /// a per-frame recompute. `@ObservationIgnored` keeps the cache out of the
    /// observation graph (mutating it must not invalidate views).
    @ObservationIgnored private var edgeCache: [String: [InferredEdge]] = [:]

    /// Inferred edges for a tool id (empty when the id is unknown). Cached.
    func inferredEdges(for id: String) -> [InferredEdge] {
        if let cached = edgeCache[id] { return cached }
        guard let tool = UniverseSeed.tools.first(where: { $0.id == id }) else {
            edgeCache[id] = []
            return []
        }
        let edges = RelationshipIntelligence.infer(candidate: tool, universe: UniverseSeed.tools)
        edgeCache[id] = edges
        return edges
    }

    // MARK: - Derived state

    var selectedCategoryModel: ToolCategory {
        UniverseSeed.category(selection.activeCategory)
    }

    /// Tools for the active category, falling back to the core slice so
    /// the rail never renders empty (Phase 1 parity).
    var visibleTools: [Tool] {
        let tools = UniverseSeed.tools(in: selection.activeCategory)
        return tools.isEmpty ? UniverseSeed.tools.filter { $0.category == .core } : tools
    }

    var selectedTool: Tool {
        UniverseSeed.tools.first { $0.id == selection.selectedToolID }
            ?? visibleTools.first
            ?? UniverseSeed.tools[0]
    }

    /// Ranked matches via `SearchCore` (name-prefix > name > summary >
    /// category short-name, capped at `SearchCore.maxResults`).
    /// Whitespace-only queries return nothing so the search dock can
    /// treat "no text" and "no results" identically.
    var searchResults: [Tool] {
        SearchCore.results(for: searchQuery, in: UniverseSeed.tools) { UniverseSeed.category($0).shortName }
    }

    /// Web parity: FindBar.tsx:196 `tools.filter(userAdded).slice(-6).reverse()`.
    /// Most-recent-first, de-duplicated per tool, capped at six.
    var recentHistory: [ToolHistory.Event] {
        history.recents(limit: 6)
    }

    // MARK: - Intents

    func selectCategory(_ id: ToolCategoryId) {
        // Phase 1 parity: .onChange(of:) was equality-gated, so re-tapping
        // the active category chip must not reset the tool selection.
        guard selection.activeCategory != id else { return }
        selection.activeCategory = id
        selection.selectedToolID = UniverseSeed.tools(in: id).first?.id ?? "founder-os"
    }

    func selectTool(_ id: String) {
        selection.selectedToolID = id
    }

    /// Selects a tool from any surface that can name a tool id: node tap,
    /// search result, or relation row. Returns false when the id is not
    /// in the seed so callers can skip haptics for stale references.
    @discardableResult
    func focusTool(_ id: String) -> Bool {
        guard let tool = UniverseSeed.tools.first(where: { $0.id == id }) else { return false }
        selection.activeCategory = tool.category
        selection.selectedToolID = tool.id
        clarityMode = .focus
        return true
    }

    func setHover(_ id: String?) {
        selection.hoveredToolID = id
    }

    /// Record that a tool was added to the universe. Persists immediately so
    /// the strip survives relaunch.
    func recordAdded(_ toolID: String) {
        history.record(toolID: toolID, kind: .added)
        historyStore?.save(history)
    }

    /// Record that a tool was removed from the universe.
    func recordDeleted(_ toolID: String) {
        history.record(toolID: toolID, kind: .deleted)
        historyStore?.save(history)
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
}
