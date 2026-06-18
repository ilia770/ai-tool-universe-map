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

/// User-facing visualization presets. The letters intentionally match
/// the design research shortlist: A/K/N/O, with N as the force-3D view.
enum VisualizationStyle: String, CaseIterable, Identifiable, Equatable, Sendable {
    case atlasOverlay
    case kineticPockets
    case force3D
    case orbitalGlass

    var id: String { rawValue }

    var shortLabel: String {
        switch self {
        case .atlasOverlay: return "A"
        case .kineticPockets: return "K"
        case .force3D: return "N"
        case .orbitalGlass: return "O"
        }
    }

    var title: String {
        switch self {
        case .atlasOverlay: return "Atlas Overlay"
        case .kineticPockets: return "Kinetic Pockets"
        case .force3D: return "N Stage Universe"
        case .orbitalGlass: return "Orbital Glass"
        }
    }

    var detail: String {
        switch self {
        case .atlasOverlay: return "Labels-first overview for fast scanning."
        case .kineticPockets: return "Roomier pocket worlds with stronger motion."
        case .force3D: return "Animated 3D stage path for moving across the workflow."
        case .orbitalGlass: return "Soft glass orbits tuned for calm browsing."
        }
    }

    var nodeScale: Float {
        switch self {
        case .atlasOverlay: return 0.92
        case .kineticPockets: return 1.05
        case .force3D: return 1.16
        case .orbitalGlass: return 1.0
        }
    }

    var categoryScale: Float {
        switch self {
        case .atlasOverlay: return 0.94
        case .kineticPockets: return 1.08
        case .force3D: return 1.14
        case .orbitalGlass: return 1.0
        }
    }

    var glowBoost: Float {
        switch self {
        case .atlasOverlay: return 0.82
        case .kineticPockets: return 1.1
        case .force3D: return 1.32
        case .orbitalGlass: return 1.0
        }
    }

    var backgroundGlow: Double {
        switch self {
        case .atlasOverlay: return 0.12
        case .kineticPockets: return 0.22
        case .force3D: return 0.28
        case .orbitalGlass: return 0.18
        }
    }
}

enum AppLanguage: String, CaseIterable, Identifiable, Equatable, Sendable {
    case system
    case english
    case russian

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "System"
        case .english: return "English"
        case .russian: return "Russian"
        }
    }
}

enum UniverseActivityKind: String, Equatable, Sendable {
    case added
    case removed
    case restored
    case focused
    case asked
}

struct UniverseActivity: Identifiable, Equatable, Sendable {
    let id: UUID
    let kind: UniverseActivityKind
    let title: String
    let detail: String
    let toolID: String?
    let createdAt: Date

    init(
        id: UUID = UUID(),
        kind: UniverseActivityKind,
        title: String,
        detail: String,
        toolID: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.detail = detail
        self.toolID = toolID
        self.createdAt = createdAt
    }
}

struct AssistantMessage: Identifiable, Equatable, Sendable {
    enum Role: String, Equatable, Sendable {
        case user
        case assistant
    }

    let id: UUID
    let role: Role
    let text: String
    let matchIDs: [String]
    let createdAt: Date

    init(
        id: UUID = UUID(),
        role: Role,
        text: String,
        matchIDs: [String] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.matchIDs = matchIDs
        self.createdAt = createdAt
    }
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
