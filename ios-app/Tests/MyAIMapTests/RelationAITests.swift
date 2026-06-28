import Testing
@testable import MyAIMap

@Suite("RelationAI — parse + prompt")
struct RelationAITests {

    private let catalog: Set<String> = ["a", "b", "c", "d"]

    @Test func parsesCleanJSONArray() {
        let ids = RelationAI.parseRelatedIDs(from: #"["b","c"]"#, catalog: catalog, excluding: "a")
        #expect(ids == ["b", "c"])
    }

    @Test func parsesArrayEmbeddedInProse() {
        let reply = "Sure! Related: [\"b\", \"d\"] — hope that helps."
        let ids = RelationAI.parseRelatedIDs(from: reply, catalog: catalog, excluding: "a")
        #expect(ids == ["b", "d"])
    }

    @Test func dropsSelfUnknownAndDuplicates() {
        let ids = RelationAI.parseRelatedIDs(from: #"["a","b","b","ghost","c"]"#, catalog: catalog, excluding: "a")
        #expect(ids == ["b", "c"]) // self 'a' dropped, 'ghost' not in catalog, 'b' deduped
    }

    @Test func respectsLimit() {
        let ids = RelationAI.parseRelatedIDs(from: #"["a","b","c","d"]"#, catalog: catalog, excluding: "x", limit: 2)
        #expect(ids.count == 2)
    }

    @Test func emptyOnGarbage() {
        let ids = RelationAI.parseRelatedIDs(from: "no ids here at all", catalog: catalog, excluding: "a")
        #expect(ids.isEmpty)
    }

    @Test func promptMentionsToolAndCatalog() {
        let tool = Tool(id: "a", name: "Alpha", category: .coding, summary: "Does things",
                        stage: .execution, orbit: .middle, angle: 0, url: nil,
                        logoDomain: nil, relationIds: [], classification: nil)
        let other = Tool(id: "b", name: "Beta", category: .coding, summary: "",
                         stage: .execution, orbit: .middle, angle: 0, url: nil,
                         logoDomain: nil, relationIds: [], classification: nil)
        let p = RelationAI.prompt(for: tool, in: [tool, other])
        #expect(p.contains("Alpha"))
        #expect(p.contains("b: Beta"))
        #expect(!p.contains("a: Alpha")) // self excluded from catalog list
    }
}
