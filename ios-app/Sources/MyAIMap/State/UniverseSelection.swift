import Foundation

/// Camera framing mode, mirroring the web `CameraController` prop
/// `viewMode: 'overview' | 'pocket' | 'node'`.
/// `.node` is reserved for the focus-on-tool camera that lands with the
/// gesture PR; nothing derives it yet.
enum ViewMode: Equatable, Sendable {
    case overview
    case pocket
    case node
}

/// Map clarity mode, mirroring the web F / C / A keyboard shortcuts.
/// Phase 2 stores it in the view-model; the UI toggle lands with the
/// SearchDock / Sheets PRs.
enum ClarityMode: String, CaseIterable, Equatable, Sendable {
    case focus
    case context
    case atlas
}

/// Pure selection state. Lives in its own value type so the view-model
/// can hand a snapshot to views (and future ECS systems) without
/// exposing the whole observable object.
struct UniverseSelection: Equatable, Sendable {
    var activeCategory: ToolCategoryId = .core
    var selectedToolID: String = "founder-os"
    var hoveredToolID: String? = nil

    /// Overview when the core universe is showing, pocket once a
    /// category world is active. `.node` arrives with tap-to-focus.
    var viewMode: ViewMode {
        activeCategory == .core ? .overview : .pocket
    }
}
