import Testing
import Foundation
@testable import MyAIMap

@Suite("RelationshipIntelligence — pinpoint, explained edges")
struct RelationshipIntelligenceTests {

    @Test func chromeExtensionLinksToGoogleNotUnrelated() {
        let universe = RelationshipFixtures.universe
        let cand = RelationshipFixtures.candidate("g-ext")
        let edges = RelationshipIntelligence.infer(candidate: cand, universe: universe)
        let toGoogle = edges.first { $0.toId == "google" }
        #expect(toGoogle?.kind == .extensionOf)
        #expect(!edges.contains { $0.toId == "figma" })
    }

    @Test func sameCategoryPeerIsAlternativeTo() {
        let edges = RelationshipIntelligence.infer(
            candidate: RelationshipFixtures.candidate("windsurf"),
            universe: RelationshipFixtures.universe)
        #expect(edges.first { $0.toId == "cursor" }?.kind == .alternativeTo)
    }

    @Test func hubDoesNotOverConnect() {
        let cand = RelationshipFixtures.tool(id: "google", name: "Google", category: .research, stage: .research)
        let many = [cand] + (0..<30).map {
            RelationshipFixtures.tool(id: "coder-\($0)", name: "Coder \($0)", category: .coding, stage: .execution)
        }
        let edges = RelationshipIntelligence.infer(candidate: cand, universe: many)
        #expect(edges.count <= 12)
        #expect(!edges.contains { $0.toId == "coder-0" })
    }

    @Test func fixtureCasesHoldOnBothLanes() {
        // Cross-lane contract: same cases the web `relationship-fixtures.test.ts`
        // asserts must hold against the Swift engine.
        for c in RelationshipFixtures.cases {
            let edges = RelationshipIntelligence.infer(candidate: c.candidate, universe: RelationshipFixtures.universe)
            for e in c.expect {
                #expect(edges.first { $0.toId == e.toId }?.kind == e.kind)
            }
            for id in c.forbid ?? [] {
                #expect(!edges.contains { $0.toId == id })
            }
        }
    }
}
