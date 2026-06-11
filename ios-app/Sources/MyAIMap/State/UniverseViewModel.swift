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
