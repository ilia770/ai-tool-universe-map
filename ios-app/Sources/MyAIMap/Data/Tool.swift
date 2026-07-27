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
struct Tool: Identifiable, Codable, Equatable, Sendable {
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

    struct Classification: Codable, Equatable, Sendable {
        let confidence: Double
        let matchedKeywords: [String]
        let reason: String
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
