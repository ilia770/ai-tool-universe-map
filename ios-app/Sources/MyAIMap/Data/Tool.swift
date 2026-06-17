import Foundation

/// Workflow stages, matching the web app's `WorkflowStageId`.
enum WorkflowStageId: String, CaseIterable, Codable, Sendable {
    case research
    case planning
    case execution
    case approval
    case review
}

/// Orbit ring index. `core` is the centre slot; rings 1-3 are concentric.
enum OrbitRing: Int, Codable, Sendable {
    case core = 0
    case inner = 1
    case middle = 2
    case outer = 3
}

/// One service / tool. Direct mirror of the web app's `AITool` shape so
/// the JSON migration we do later can deserialize the same payload.
struct Tool: Identifiable, Codable, Sendable {
    let id: String
    let name: String
    let category: ToolCategoryId
    let summary: String
    let stage: WorkflowStageId
    let orbit: OrbitRing
    let angle: Float
    let url: URL?
    let logoDomain: String?
    let relationIds: [String]
    let classification: Classification?
    /// `true` when the tool was added by the user at runtime; `false` for every
    /// seed tool. The seed JSON carries no such key, so the custom Decodable init
    /// below backfills it to `false` via `decodeIfPresent`.
    var userAdded: Bool = false

    struct Classification: Codable, Sendable {
        let confidence: Double
        let matchedKeywords: [String]
        let reason: String
    }
}

// MARK: - Custom Decodable (backfill userAdded)

/// The custom `init(from:)` lives in an extension so Swift still generates the
/// memberwise initialiser — existing call sites that construct Tool literals
/// (tests, fixtures) continue to compile unchanged; `userAdded` is appended as
/// a parameter with its default value of `false`.
extension Tool {
    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id            = try c.decode(String.self,           forKey: .id)
        name          = try c.decode(String.self,           forKey: .name)
        category      = try c.decode(ToolCategoryId.self,   forKey: .category)
        summary       = try c.decode(String.self,           forKey: .summary)
        stage         = try c.decode(WorkflowStageId.self,  forKey: .stage)
        orbit         = try c.decode(OrbitRing.self,        forKey: .orbit)
        angle         = try c.decode(Float.self,            forKey: .angle)
        url           = try c.decodeIfPresent(URL.self,     forKey: .url)
        logoDomain    = try c.decodeIfPresent(String.self,  forKey: .logoDomain)
        relationIds   = try c.decode([String].self,         forKey: .relationIds)
        classification = try c.decodeIfPresent(Classification.self, forKey: .classification)
        // Seed JSON has no `userAdded` key → backfill to false.
        userAdded     = try c.decodeIfPresent(Bool.self,    forKey: .userAdded) ?? false
    }
}

/// A directed (-ish) link between two tools. Phase 0 ignores the optional
/// `confidence`, but the field is in place so the iOS port stays at parity
/// with the web app's `UniverseLink`.
struct UniverseLink: Codable, Sendable {
    enum Strength: String, Codable, Sendable {
        case primary
        case secondary
    }

    let source: String
    let target: String
    let strength: Strength
    let label: String
    let confidence: Double?
}
