import Foundation

/// Typed relationship edge kinds. Mirror of the web `RELATION_KINDS`
/// (`src/lib/relationship-intelligence.types.ts`) — raw values are the
/// same hyphenated strings so the shared fixtures decode on both lanes.
enum RelationKind: String, Codable, Sendable, CaseIterable {
    case extensionOf = "extension-of"
    case integratesWith = "integrates-with"
    case sameVendor = "same-vendor"
    case dataFlowsTo = "data-flows-to"
    case alternativeTo = "alternative-to"
}

/// A pinpoint, explained, confidence-scored relationship edge. Additive to
/// `Tool.relationIds`; derived at runtime, never persisted. Parity with the
/// web `InferredEdge` (`relationship-intelligence.types.ts`).
struct InferredEdge: Codable, Sendable, Equatable {
    let fromId: String
    let toId: String
    let kind: RelationKind
    let reason: String
    let confidence: Double
}

/// Pure relationship inference engine — a rule-for-rule port of the web
/// `inferRelationships` (`src/lib/relationship-intelligence.ts`). Same
/// thresholds, same scoring order, same per-kind cap (which stops a hub
/// from over-connecting), same deterministic sort. Foundation only — no
/// RealityKit / SwiftUI — so it is unit-testable in `MyAIMapTests`.
enum RelationshipIntelligence {
    static let confidenceThreshold = 0.4
    static let maxEdgesPerKind = 4
    private static let stageOrder: [WorkflowStageId] = [.research, .planning, .execution, .approval, .review]

    // Matches "chrome/browser/firefox/edge? extension|add-on|plugin".
    private static let extensionPattern = "\\b(chrome|browser|firefox|edge)?\\s*(extension|add-?on|plugin)\\b"

    static func infer(candidate: Tool, universe: [Tool], knowledge: KnowledgeStore.Type? = nil) -> [InferredEdge] {
        let text = haystack(candidate, knowledge?.knowledge(for: candidate.id))
        let scored: [InferredEdge] = universe
            .filter { $0.id != candidate.id }
            .compactMap { target -> InferredEdge? in
                guard let s = score(candidate, target, text) else { return nil }
                guard s.confidence >= confidenceThreshold else { return nil }
                return InferredEdge(fromId: candidate.id, toId: target.id,
                                    kind: s.kind, reason: s.reason, confidence: s.confidence)
            }

        // Cap per kind (stops hub over-connect), then deterministic sort.
        var byKind: [RelationKind: [InferredEdge]] = [:]
        for e in scored { byKind[e.kind, default: []].append(e) }
        var capped: [InferredEdge] = []
        for (_, list) in byKind {
            let sorted = list.sorted {
                $0.confidence > $1.confidence || ($0.confidence == $1.confidence && $0.toId < $1.toId)
            }
            capped.append(contentsOf: sorted.prefix(maxEdgesPerKind))
        }
        return capped.sorted {
            if $0.confidence != $1.confidence { return $0.confidence > $1.confidence }
            if $0.kind.rawValue != $1.kind.rawValue { return $0.kind.rawValue < $1.kind.rawValue }
            return $0.toId < $1.toId
        }
    }

    // MARK: - Scoring (mirrors scorePair in the TS engine)

    private struct Scored {
        let kind: RelationKind
        let confidence: Double
        let reason: String
    }

    private static func score(_ cand: Tool, _ target: Tool, _ text: String) -> Scored? {
        let namesTarget = nameTokens(target).contains { text.contains($0) }

        // 1. extension-of
        if matchesExtension(text) && namesTarget {
            return Scored(kind: .extensionOf, confidence: 0.82,
                          reason: "It is an extension/add-on built for \(target.name).")
        }
        // 2. same-vendor
        if let cv = registrable(cand.logoDomain), let tv = registrable(target.logoDomain), cv == tv {
            let brand = target.name.split(separator: " ").first.map(String.init) ?? target.name
            return Scored(kind: .sameVendor, confidence: 0.78,
                          reason: "Both are part of the \(brand) family (same vendor).")
        }
        // 3. integrates-with
        if namesTarget && nameTokens(target).joined().count >= 4 {
            return Scored(kind: .integratesWith, confidence: 0.6,
                          reason: "It explicitly works with \(target.name).")
        }
        // 4. data-flows-to
        if cand.category == target.category,
           let ti = stageOrder.firstIndex(of: target.stage),
           let ci = stageOrder.firstIndex(of: cand.stage),
           ti == ci + 1 {
            return Scored(kind: .dataFlowsTo, confidence: 0.5,
                          reason: "Output from this stage typically flows into \(target.name).")
        }
        // 5. alternative-to
        if cand.category == target.category && cand.stage == target.stage {
            return Scored(kind: .alternativeTo, confidence: 0.45,
                          reason: "A category alternative to \(target.name).")
        }
        return nil
    }

    // MARK: - Helpers (mirror the TS helpers)

    private static func matchesExtension(_ text: String) -> Bool {
        text.range(of: extensionPattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    /// Last two dot-segments of a domain, lowercased; nil when absent.
    private static func registrable(_ domain: String?) -> String? {
        guard let domain, !domain.isEmpty else { return nil }
        let parts = domain.lowercased().split(separator: ".")
        guard !parts.isEmpty else { return nil }
        return parts.suffix(2).joined(separator: ".")
    }

    /// Lowercased blob of everything we know, matching the TS haystack order.
    private static func haystack(_ t: Tool, _ k: Knowledge?) -> String {
        [t.name, t.summary, k?.whatFor ?? "", t.logoDomain ?? "", t.url?.absoluteString ?? ""]
            .joined(separator: " ").lowercased()
    }

    /// Lowercased name tokens of length >= 3, split on non-alphanumerics.
    private static func nameTokens(_ t: Tool) -> [String] {
        t.name.lowercased()
            .split { !($0.isLetter || $0.isNumber) }
            .map(String.init)
            .filter { $0.count >= 3 }
    }
}
