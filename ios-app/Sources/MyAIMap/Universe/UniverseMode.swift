import Foundation

/// Navigation state for the AI Universe Map.
///
/// The 3D map should drive navigation, so scene visibility, labels, camera
/// framing, and bottom UI all derive from this mode instead of ad-hoc
/// selected-category checks.
enum UniverseMode: Equatable, Sendable {
    case overview
    case branchFocus(ToolCategoryId)
    case toolSelected(ToolCategoryId, String)
    case detail(ToolCategoryId, String)
    case chatOpen(ToolCategoryId?, String?)

    var focusedCategory: ToolCategoryId {
        switch self {
        case .overview:
            return .core
        case .branchFocus(let category),
             .toolSelected(let category, _),
             .detail(let category, _):
            return category
        case .chatOpen(let category, _):
            return category ?? .core
        }
    }

    var selectedToolID: String? {
        switch self {
        case .overview, .branchFocus:
            return nil
        case .toolSelected(_, let toolID),
             .detail(_, let toolID):
            return toolID
        case .chatOpen(_, let toolID):
            return toolID
        }
    }

    var signature: String {
        switch self {
        case .overview:
            return "overview"
        case .branchFocus(let category):
            return "branch:\(category.rawValue)"
        case .toolSelected(let category, let toolID):
            return "tool:\(category.rawValue):\(toolID)"
        case .detail(let category, let toolID):
            return "detail:\(category.rawValue):\(toolID)"
        case .chatOpen(let category, let toolID):
            return "chat:\(category?.rawValue ?? "none"):\(toolID ?? "none")"
        }
    }

    var showsSatellites: Bool {
        switch self {
        case .branchFocus, .toolSelected:
            // Core renders founder-os as the central planet; its other tools
            // (e.g. OpenSwarm) appear as satellites. addSatellites skips the
            // central founder-os so it is not double-rendered.
            return true
        case .overview, .detail, .chatOpen:
            return false
        }
    }

    var showsPlanetLabels: Bool {
        switch self {
        case .overview, .branchFocus, .toolSelected:
            return true
        case .detail, .chatOpen:
            return false
        }
    }

    var showsToolAnchor: Bool {
        if case .toolSelected = self { return true }
        return false
    }

    var showsToolLabels: Bool {
        switch self {
        case .branchFocus, .toolSelected:
            return true
        case .overview, .detail, .chatOpen:
            return false
        }
    }

    var isChatOpen: Bool {
        if case .chatOpen = self { return true }
        return false
    }

    var isDetailOpen: Bool {
        if case .detail = self { return true }
        return false
    }

    var allowsMapGestures: Bool {
        switch self {
        case .overview, .branchFocus, .toolSelected:
            return true
        case .detail, .chatOpen:
            return false
        }
    }

    var mapOpacity: Double {
        switch self {
        case .overview, .branchFocus, .toolSelected:
            return 1
        case .detail:
            return 0.18
        case .chatOpen:
            // Chat is a secondary input layer, not a takeover: the universe
            // stays visible/atmospheric so focusing the input never blacks out
            // the app (see docs/UI_STATE_MACHINE.md, INPUT_CHAT_SPEC.md).
            return 0.7
        }
    }

    var mapBlurRadius: Double {
        switch self {
        case .overview, .branchFocus, .toolSelected:
            return 0
        case .detail:
            return 1.8
        case .chatOpen:
            return 1.0
        }
    }

    var dimOpacity: Double {
        switch self {
        case .overview, .branchFocus, .toolSelected:
            return 0
        case .detail:
            return 0.64
        case .chatOpen:
            // Light scrim only — keep the universe readable behind chat.
            return 0.18
        }
    }

    var orbitOpacityMultiplier: Float {
        switch self {
        case .overview:
            return 0.26
        case .branchFocus, .toolSelected:
            return 0.15
        case .detail:
            return 0.0
        case .chatOpen:
            return 0.0
        }
    }

    func isPrimaryPlanet(_ category: ToolCategoryId) -> Bool {
        switch self {
        case .overview:
            return category == .core
        case .branchFocus, .toolSelected, .detail, .chatOpen:
            return category == focusedCategory
        }
    }

    func planetOpacity(for category: ToolCategoryId) -> Float {
        switch self {
        case .overview:
            return category == .core ? 0.92 : 0.88
        case .branchFocus, .toolSelected:
            if category == focusedCategory { return 1 }
            if category == .core { return 0.34 }
            return 0.30
        case .detail:
            if category == focusedCategory { return 0.18 }
            if category == .core { return 0.045 }
            return 0.025
        case .chatOpen:
            // Chat is a secondary input layer, not a takeover. Keep planets
            // clearly visible (atmospheric) so focusing the input never blacks
            // out the universe. (detail, above, stays heavily dimmed — it is a
            // full reading sheet, not an input overlay.)
            if category == focusedCategory { return 0.7 }
            if category == .core { return 0.6 }
            return 0.5
        }
    }

    func satelliteOpacity(for toolID: String) -> Float {
        switch self {
        case .branchFocus:
            return 0.82
        case .toolSelected(_, let selectedID):
            return selectedID == toolID ? 1 : 0.36
        case .overview, .detail, .chatOpen:
            return 0
        }
    }
}
