import Foundation

/// Bidirectional neighbour map for the Bloom graph (variant K). Built from the
/// shared `ConnectionResolver`, but the weak "constellation" kind (every tool in
/// the same category) is dropped so each node has only a handful of *meaningful*
/// neighbours — the sparse, legible relation set the Bloom reveal needs.
enum BloomAdjacency {

    /// Kinds that count as a real relation worth blooming to.
    private static let meaningful: Set<ConnectionKind> = [.curated, .ai, .alternative, .pipeline]

    /// `[toolID: [neighbourID]]`, symmetric (if A→B then B→A).
    static func build(tools: [Tool]) -> [String: [String]] {
        var sets: [String: Set<String>] = [:]
        for tool in tools { sets[tool.id] = [] }
        for tool in tools {
            for c in ConnectionResolver.connections(for: tool, in: tools)
            where meaningful.contains(c.kind) {
                sets[tool.id, default: []].insert(c.targetID)
                sets[c.targetID, default: []].insert(tool.id)
            }
        }
        return sets.mapValues { $0.sorted() }
    }

    /// Unique undirected edges among `tools` (each pair once, a < b by id).
    static func edges(tools: [Tool]) -> [(a: String, b: String)] {
        let adj = build(tools: tools)
        var seen = Set<String>()
        var result: [(String, String)] = []
        for (id, neighbours) in adj {
            for nb in neighbours {
                let key = id < nb ? "\(id)|\(nb)" : "\(nb)|\(id)"
                if seen.insert(key).inserted {
                    result.append(id < nb ? (id, nb) : (nb, id))
                }
            }
        }
        return result.sorted { $0.0 == $1.0 ? $0.1 < $1.1 : $0.0 < $1.0 }
    }
}
