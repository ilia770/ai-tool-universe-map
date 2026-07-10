import RealityKit
import Testing
@testable import MyAIMap

/// Persistent-scene acceptance tests (docs/UNIVERSE_QA_CHECKLIST.md, Phase 2):
/// planet entity IDENTITY must survive every selection/mode change — the same
/// `Entity` objects, mutated in place, never recreated. Only structural
/// changes (tool set) may create/destroy planet entities.
@Suite("UniverseSceneController — persistent planet registry")
@MainActor
struct UniverseSceneRegistryTests {

    private func tool(_ id: String, category: ToolCategoryId) -> Tool {
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

    private func makeController(tools: [Tool]) -> (UniverseSceneController, [PlanetData]) {
        let planets = PlanetData.makePlanets(categories: UniverseSeed.categories, tools: tools)
        let controller = UniverseSceneController()
        _ = controller.makeScene(
            planets: planets,
            mode: .overview,
            visualizationStyle: .orbitalGlass,
            cameraRig: CameraRigController(),
            reduceMotion: true,
            active: true
        )
        return (controller, planets)
    }

    private func rootIdentities(_ controller: UniverseSceneController) -> [ToolCategoryId: ObjectIdentifier] {
        controller.registry.mapValues { ObjectIdentifier($0.root) }
    }

    @Test func selectionAndModeChangesPreserveEntityIdentity() {
        let tools = [
            tool("founder-os", category: .core),
            tool("figma", category: .design),
            tool("framer", category: .design),
            tool("posthog", category: .analytics),
        ]
        let (controller, planets) = makeController(tools: tools)
        let before = rootIdentities(controller)
        #expect(!before.isEmpty)

        // Walk every navigation state the app can reach; none may recreate a
        // planet entity.
        let modes: [UniverseMode] = [
            .branchFocus(.design),
            .toolSelected(.design, "figma"),
            .detail(.design, "figma"),
            .chatOpen(.design, "figma"),
            .toolSelected(.design, "framer"),
            .branchFocus(.analytics),
            .overview,
        ]
        for mode in modes {
            controller.update(
                planets: planets,
                mode: mode,
                visualizationStyle: .orbitalGlass,
                reduceMotion: true,
                active: true
            )
            #expect(rootIdentities(controller) == before, "entity recreated in \(mode.signature)")
        }
    }

    @Test func renderModeToggleKeepsScene() {
        let tools = [tool("founder-os", category: .core), tool("figma", category: .design)]
        let (controller, planets) = makeController(tools: tools)
        let before = rootIdentities(controller)

        // Hide (2D shown) then re-show — entities stay alive throughout.
        for active in [false, true, false, true] {
            controller.update(
                planets: planets,
                mode: .overview,
                visualizationStyle: .orbitalGlass,
                reduceMotion: true,
                active: active
            )
            #expect(rootIdentities(controller) == before)
        }
    }

    @Test func toolSetChangeDiffsOnlyAffectedPlanets() {
        let tools = [
            tool("founder-os", category: .core),
            tool("figma", category: .design),
            tool("posthog", category: .analytics),
        ]
        let (controller, _) = makeController(tools: tools)
        let before = rootIdentities(controller)

        // Add an analytics tool: analytics' radius (tool count) changes → that
        // planet may be structurally recreated; core/design keep identity when
        // their geometry inputs are unchanged. (Positions depend on the branch
        // count, which is stable here — categories don't change.)
        let grown = tools + [tool("amplitude", category: .analytics)]
        let grownPlanets = PlanetData.makePlanets(categories: UniverseSeed.categories, tools: grown)
        controller.update(
            planets: grownPlanets,
            mode: .overview,
            visualizationStyle: .orbitalGlass,
            reduceMotion: true,
            active: true
        )
        let after = rootIdentities(controller)
        #expect(after[.core] == before[.core])
        #expect(after[.design] == before[.design])
        #expect(after.count == before.count)
    }

    @Test func dormantUntilFirstActivation() {
        let planets = PlanetData.makePlanets(
            categories: UniverseSeed.categories,
            tools: [tool("founder-os", category: .core)]
        )
        let controller = UniverseSceneController()
        _ = controller.makeScene(
            planets: planets,
            mode: .overview,
            visualizationStyle: .orbitalGlass,
            cameraRig: CameraRigController(),
            reduceMotion: true,
            active: false
        )
        // 2D-default launch: no planet entities built yet.
        #expect(controller.registry.isEmpty)

        controller.update(
            planets: planets,
            mode: .overview,
            visualizationStyle: .orbitalGlass,
            reduceMotion: true,
            active: true
        )
        #expect(!controller.registry.isEmpty)
    }

    // RK.2.2: tool selection within a focused category must MUTATE the same
    // satellite entities, not recreate them. Only leaving the category drops
    // the branch.
    @Test func toolSelectionPreservesSatelliteIdentity() {
        let tools = [
            tool("founder-os", category: .core),
            tool("figma", category: .design),
            tool("framer", category: .design),
            tool("sketch", category: .design),
        ]
        let (controller, planets) = makeController(tools: tools)

        controller.update(
            planets: planets, mode: .branchFocus(.design),
            visualizationStyle: .orbitalGlass, reduceMotion: true, active: true
        )
        guard let branch = controller.satelliteBranch else {
            Issue.record("no satellite branch after branchFocus")
            return
        }
        let before = branch.toolRootIdentities
        #expect(before.count == 3)

        for mode in [UniverseMode.toolSelected(.design, "figma"),
                     .toolSelected(.design, "framer"),
                     .branchFocus(.design)] {
            controller.update(
                planets: planets, mode: mode,
                visualizationStyle: .orbitalGlass, reduceMotion: true, active: true
            )
            #expect(controller.satelliteBranch === branch, "branch recreated in \(mode.signature)")
            #expect(controller.satelliteBranch?.toolRootIdentities == before)
        }

        // Leaving the category drops the branch (transient reveal layer).
        controller.update(
            planets: planets, mode: .overview,
            visualizationStyle: .orbitalGlass, reduceMotion: true, active: true
        )
        #expect(controller.satelliteBranch == nil)
    }

    @Test func geometryMatchesDetectsRadiusChange() {
        let a = PlanetData.makePlanets(
            categories: UniverseSeed.categories,
            tools: [tool("founder-os", category: .core), tool("figma", category: .design)]
        )
        let b = PlanetData.makePlanets(
            categories: UniverseSeed.categories,
            tools: [tool("founder-os", category: .core), tool("figma", category: .design), tool("framer", category: .design)]
        )
        let designA = a.first { $0.id == .design }!
        let designB = b.first { $0.id == .design }!
        #expect(!UniverseSceneController.geometryMatches(designA, designB)) // radius grew
        #expect(UniverseSceneController.geometryMatches(designA, designA))
    }
}
