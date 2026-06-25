import Testing
@testable import MyAIMap

/// F3 (deleted tool reappears in 3D): the RealityKit scene only rebuilds when
/// its signature changes. The signature must reflect the actual visible tool
/// set, not just per-category counts, so a removed (or swapped) tool always
/// forces a rebuild and its satellite drops out of the scene.
@Suite("UniverseSceneController — scene signature tracks the tool set")
@MainActor
struct UniverseSceneSignatureTests {

    private func tool(_ id: String, category: ToolCategoryId = .analytics) -> Tool {
        Tool(
            id: id,
            name: id.capitalized,
            category: category,
            summary: "Test tool.",
            stage: .research,
            orbit: .middle,
            angle: 0,
            url: nil,
            logoDomain: nil,
            relationIds: [],
            classification: nil
        )
    }

    private func signature(for tools: [Tool]) -> String {
        let planets = PlanetData.makePlanets(categories: UniverseSeed.categories, tools: tools)
        return UniverseSceneController.sceneSignature(
            planets: planets,
            mode: .overview,
            visualizationStyle: .orbitalGlass,
            reduceMotion: true
        )
    }

    @Test func removingAToolChangesTheSignature() {
        let before = signature(for: [tool("alpha"), tool("beta")])
        let after = signature(for: [tool("alpha")])
        #expect(before != after)
    }

    /// The exact F3 bug: deleting one tool and adding another in the SAME
    /// category keeps the per-category count identical. A count-only signature
    /// stayed unchanged → no rebuild → the deleted tool's satellite persisted.
    @Test func swappingToolsAtSameCountStillChangesTheSignature() {
        let before = signature(for: [tool("github"), tool("beta")])
        let after = signature(for: [tool("gitlab"), tool("beta")])
        #expect(before != after)
    }

    @Test func identicalToolSetsProduceIdenticalSignatures() {
        let a = signature(for: [tool("alpha"), tool("beta")])
        let b = signature(for: [tool("alpha"), tool("beta")])
        #expect(a == b)
    }
}
