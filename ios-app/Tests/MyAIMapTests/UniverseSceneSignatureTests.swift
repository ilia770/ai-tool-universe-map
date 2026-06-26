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

    /// G1 (empty 3D scene on return): on a fresh `RealityView` mount the
    /// controller resets its cached signature to `""` to force a full rebuild
    /// of the dynamic entity graph, even when the scene inputs are unchanged.
    /// That only works if a real signature is never itself the empty string —
    /// otherwise the rebuild gate (`signature != cached`) could short-circuit
    /// and the scene would come back empty. Guard that invariant here.
    @Test func realSignatureIsNeverEmptySoMountAlwaysForcesRebuild() {
        let real = signature(for: [tool("alpha"), tool("beta")])
        #expect(!real.isEmpty)
        // The reset sentinel used by `makeScene` must differ from any real
        // signature so `rebuildIfNeeded` always re-enters after a remount.
        #expect(real != "")
    }
}
