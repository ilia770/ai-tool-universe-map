import Foundation

/// "Connected because …" copy for an inferred edge. Parity with the web
/// `connectedBecause` (`src/playground/relationshipReason.ts`) — same labels,
/// same `Label · reason (NN%)` shape.
enum RelationshipReason {
    static func label(_ kind: RelationKind) -> String {
        switch kind {
        case .extensionOf: return "Extension of"
        case .integratesWith: return "Integrates with"
        case .sameVendor: return "Same vendor"
        case .dataFlowsTo: return "Feeds into"
        case .alternativeTo: return "Alternative to"
        }
    }

    static func connectedBecause(_ edge: InferredEdge) -> String {
        "\(label(edge.kind)) · \(edge.reason) (\(Int((edge.confidence * 100).rounded()))%)"
    }
}
