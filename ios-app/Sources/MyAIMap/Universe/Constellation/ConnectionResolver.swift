import Foundation

/// A typed connection from one tool to another. `kind.rawValue` is the
/// priority (lower = stronger); the resolver keeps the strongest kind per
/// target and returns connections sorted strongest-first.
enum ConnectionKind: Int, Equatable, Sendable {
    case curated = 0       // hand-filled relationIds
    case ai = 1            // AI-resolved (Phase 2; defined now so the type is stable)
    case alternative = 2   // same category + same stage ("what could replace this")
    case pipeline = 3      // same category + next workflow stage ("what comes after")
    case constellation = 4 // same category, other stage (weak grouping)
}

struct Connection: Equatable, Sendable {
    let targetID: String
    let kind: ConnectionKind
}

/// Pure derivation of tool→tool connections from real signals (category +
/// workflow stage + any curated relationIds). No UI, no async — shared by the
/// 2D and 3D renderers and fully unit-tested. The AI layer (Phase 2) injects
/// `.ai` connections through `relationIds`/a cache before this runs.
enum ConnectionResolver {

    static func nextStage(after stage: WorkflowStageId) -> WorkflowStageId? {
        let all = WorkflowStageId.allCases
        guard let i = all.firstIndex(of: stage), i + 1 < all.count else { return nil }
        return all[i + 1]
    }

    /// - Parameter aiRelations: related tool ids the AI resolved for this tool
    ///   (Phase 2, served from cache). They render as `.ai` — stronger than any
    ///   derived link, weaker than a hand-curated `relationIds` entry.
    static func connections(for tool: Tool, in tools: [Tool], aiRelations: [String] = []) -> [Connection] {
        var strongest: [String: ConnectionKind] = [:]

        func offer(_ id: String, _ kind: ConnectionKind) {
            if let existing = strongest[id], existing.rawValue <= kind.rawValue { return }
            strongest[id] = kind
        }

        let catalog = Set(tools.map(\.id))
        for id in tool.relationIds where catalog.contains(id) && id != tool.id {
            offer(id, .curated)
        }
        for id in aiRelations where catalog.contains(id) && id != tool.id {
            offer(id, .ai)
        }

        let next = nextStage(after: tool.stage)
        for other in tools where other.id != tool.id && other.category == tool.category {
            if other.stage == tool.stage {
                offer(other.id, .alternative)
            } else if let next, other.stage == next {
                offer(other.id, .pipeline)
            } else {
                offer(other.id, .constellation)
            }
        }

        return strongest
            .map { Connection(targetID: $0.key, kind: $0.value) }
            .sorted { lhs, rhs in
                lhs.kind.rawValue != rhs.kind.rawValue
                    ? lhs.kind.rawValue < rhs.kind.rawValue
                    : lhs.targetID < rhs.targetID
            }
    }
}
