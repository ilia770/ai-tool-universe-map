import CoreGraphics
import Testing
@testable import MyAIMap

@Suite("UniverseGraphLayout — readable 2D graph")
struct UniverseGraphLayoutTests {

    @Test func graphContainsCategoryAndToolNodes() {
        let layout = makeLayout()

        #expect(layout.nodes.contains { $0.id == "category:analytics" })
        #expect(layout.nodes.contains { $0.id == "tool:posthog" })
        #expect(layout.edges.contains { $0.targetID == "category:analytics" })
        #expect(layout.edges.contains { $0.targetID == "tool:posthog" })
    }

    @Test func graphNodesDoNotOverlapAtIPhoneWidth() {
        let layout = makeLayout()
        let nodes = layout.nodes

        for i in nodes.indices {
            for j in nodes.indices where j > i {
                let distance = hypot(
                    nodes[i].position.x - nodes[j].position.x,
                    nodes[i].position.y - nodes[j].position.y
                )
                let minimum = nodes[i].radius + nodes[j].radius + 4
                #expect(distance >= minimum, "\(nodes[i].id) overlaps \(nodes[j].id): \(distance)")
            }
        }
    }

    @Test func selectedToolIsVisuallyMarked() {
        let layout = makeLayout(mode: .toolSelected(.analytics, "posthog"))

        let posthog = layout.nodes.first { $0.id == "tool:posthog" }
        let analytics = layout.nodes.first { $0.id == "category:analytics" }

        #expect(posthog?.isSelected == true)
        #expect(analytics?.isContext == true)
    }

    @Test func selectedCategoryIsMarkedWhenNoToolSelected() {
        let layout = makeLayout(mode: .branchFocus(.media))

        let media = layout.nodes.first { $0.id == "category:media" }
        let remotion = layout.nodes.first { $0.id == "tool:remotion" }

        #expect(media?.isSelected == true)
        #expect(remotion?.isContext == true)
    }

    @Test func userAddedToolAppearsInGraph() {
        let custom = Tool(
            id: "random-user-tool",
            name: "Random User Tool",
            category: .analytics,
            summary: "User-added analytics helper.",
            stage: .research,
            orbit: .middle,
            angle: -2,
            url: nil,
            logoDomain: nil,
            relationIds: [],
            classification: nil
        )
        let planets = PlanetData.makePlanets(
            categories: UniverseSeed.categories,
            tools: UniverseSeed.tools + [custom]
        )
        let layout = UniverseGraphLayout.make(
            planets: planets,
            mode: .toolSelected(.analytics, custom.id),
            size: CGSize(width: 393, height: 852)
        )

        #expect(layout.nodes.contains { $0.id == "tool:random-user-tool" })
        #expect(layout.edges.contains { $0.targetID == "tool:random-user-tool" })
    }

    private func makeLayout(mode: UniverseMode = .overview) -> UniverseGraphLayoutResult {
        let planets = PlanetData.makePlanets(
            categories: UniverseSeed.categories,
            tools: UniverseSeed.tools
        )
        return UniverseGraphLayout.make(
            planets: planets,
            mode: mode,
            size: CGSize(width: 393, height: 852)
        )
    }
}
