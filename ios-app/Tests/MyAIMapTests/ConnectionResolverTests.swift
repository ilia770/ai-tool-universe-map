import Testing
@testable import MyAIMap

@Suite("ConnectionResolver — derived tool connections")
struct ConnectionResolverTests {

    private func tool(_ id: String, _ category: ToolCategoryId, _ stage: WorkflowStageId,
                      relations: [String] = []) -> Tool {
        Tool(id: id, name: id, category: category, summary: "", stage: stage,
             orbit: .middle, angle: 0, url: nil, logoDomain: nil,
             relationIds: relations, classification: nil)
    }

    @Test func sameCategorySameStageIsAlternative() {
        let a = tool("a", .coding, .execution)
        let b = tool("b", .coding, .execution)
        let result = ConnectionResolver.connections(for: a, in: [a, b])
        #expect(result.contains(Connection(targetID: "b", kind: .alternative)))
    }

    @Test func sameCategoryNextStageIsPipeline() {
        let a = tool("a", .coding, .planning)
        let b = tool("b", .coding, .execution) // execution is the stage after planning
        let result = ConnectionResolver.connections(for: a, in: [a, b])
        #expect(result.contains(Connection(targetID: "b", kind: .pipeline)))
    }

    @Test func sameCategoryOtherStageIsConstellation() {
        let a = tool("a", .coding, .research)
        let b = tool("b", .coding, .review) // not same, not next
        let result = ConnectionResolver.connections(for: a, in: [a, b])
        #expect(result.contains(Connection(targetID: "b", kind: .constellation)))
    }

    @Test func differentCategoryHasNoDerivedConnection() {
        let a = tool("a", .coding, .execution)
        let b = tool("b", .design, .execution)
        let result = ConnectionResolver.connections(for: a, in: [a, b])
        #expect(!result.contains { $0.targetID == "b" })
    }

    @Test func curatedRelationWinsOverDerived() {
        let a = tool("a", .coding, .execution, relations: ["b"])
        let b = tool("b", .coding, .execution) // would be .alternative, but curated wins
        let result = ConnectionResolver.connections(for: a, in: [a, b])
        #expect(result.contains(Connection(targetID: "b", kind: .curated)))
        #expect(result.filter { $0.targetID == "b" }.count == 1) // deduped
    }

    @Test func resultIsSortedByPriorityThenID() {
        let a = tool("a", .coding, .planning)
        let alt = tool("z-alt", .coding, .planning)        // alternative (prio 2)
        let pipe = tool("y-pipe", .coding, .execution)     // pipeline (prio 3)
        let result = ConnectionResolver.connections(for: a, in: [a, pipe, alt])
        #expect(result.first?.targetID == "z-alt") // alternative before pipeline
    }

    @Test func nextStageWalksTheWorkflow() {
        #expect(ConnectionResolver.nextStage(after: .research) == .planning)
        #expect(ConnectionResolver.nextStage(after: .review) == nil)
    }

    @Test func aiRelationBecomesAIKindOverDerived() {
        let a = tool("a", .coding, .execution)
        let b = tool("b", .coding, .execution) // derived .alternative, but AI wins
        let result = ConnectionResolver.connections(for: a, in: [a, b], aiRelations: ["b"])
        #expect(result.contains(Connection(targetID: "b", kind: .ai)))
        #expect(result.filter { $0.targetID == "b" }.count == 1)
    }

    @Test func curatedStillWinsOverAI() {
        let a = tool("a", .coding, .execution, relations: ["b"]) // curated
        let b = tool("b", .coding, .execution)
        let result = ConnectionResolver.connections(for: a, in: [a, b], aiRelations: ["b"])
        #expect(result.contains(Connection(targetID: "b", kind: .curated)))
    }

    @Test func aiRelationCanCrossCategory() {
        let a = tool("a", .coding, .execution)
        let b = tool("b", .design, .execution) // different category — no derived link
        let result = ConnectionResolver.connections(for: a, in: [a, b], aiRelations: ["b"])
        #expect(result.contains(Connection(targetID: "b", kind: .ai)))
    }

    @Test func unknownAIRelationIsIgnored() {
        let a = tool("a", .coding, .execution)
        let result = ConnectionResolver.connections(for: a, in: [a], aiRelations: ["ghost"])
        #expect(!result.contains { $0.targetID == "ghost" })
    }
}
