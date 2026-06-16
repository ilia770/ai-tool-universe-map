import Testing
@testable import MyAIMap

@Suite("RelationshipReason — Connected because copy")
struct RelationshipReasonTests {
    @Test func formatsLabelReasonAndPercent() {
        let edge = InferredEdge(fromId: "x", toId: "google", kind: .extensionOf,
                                reason: "It is an extension/add-on built for Google.", confidence: 0.82)
        #expect(RelationshipReason.connectedBecause(edge)
            == "Extension of · It is an extension/add-on built for Google. (82%)")
    }
}
