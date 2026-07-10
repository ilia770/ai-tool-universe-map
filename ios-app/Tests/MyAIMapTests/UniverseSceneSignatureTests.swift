import Testing
@testable import MyAIMap

/// F3 (deleted tool reappears in 3D): the structural entity diff only runs
/// when the structure signature changes. The signature must reflect the actual
/// visible tool set, not just per-category counts, so a removed (or swapped)
/// tool always forces a re-diff and its satellite drops out of the scene.
///
/// Persistent-scene contract (docs/UNIVERSE_ARCHITECTURE.md): the signature
/// must encode ONLY structure (tool set + style). Mode/selection and Reduce
/// Motion are component mutations and must NOT appear in the key — that is
/// what guarantees a selection change never tears entities down.
@Suite("UniverseSceneController — structure signature")
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
        return UniverseSceneController.structureSignature(
            planets: planets,
            visualizationStyle: .orbitalGlass
        )
    }

    @Test func removingAToolChangesTheSignature() {
        let before = signature(for: [tool("alpha"), tool("beta")])
        let after = signature(for: [tool("alpha")])
        #expect(before != after)
    }

    /// The exact F3 bug: deleting one tool and adding another in the SAME
    /// category keeps the per-category count identical. A count-only signature
    /// stayed unchanged → no re-diff → the deleted tool's satellite persisted.
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

    /// The controller uses `structureSignature.isEmpty` as its "never built"
    /// dormancy sentinel (2D-default users don't pay the 3D build until they
    /// first switch renderers). A real signature must therefore never be the
    /// empty string, or a built scene could be mistaken for a dormant one.
    @Test func realSignatureIsNeverEmpty() {
        #expect(!signature(for: [tool("alpha")]).isEmpty)
        // Even an empty universe (no planets) must produce a non-empty key.
        #expect(!signature(for: []).isEmpty)
    }
}
