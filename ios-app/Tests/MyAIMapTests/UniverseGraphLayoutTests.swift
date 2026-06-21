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

    // MARK: - Rendered overlap contract (full sample seed)

    // The 2D graph is the DEFAULT renderer, and the full sample seed (53 tools)
    // cannot pack ~53 two-line labels into one screen without the labels
    // overlapping — even though the collision solver keeps the circles apart.
    //
    // Chosen no-overlap contract (label culling, the lower-risk fix):
    //   1. Every node *circle* is guaranteed non-overlapping at every width.
    //   2. Non-focused tool labels are culled (`showsLabel == false`), so the
    //      only labels that ever render are core, category, the selected tool,
    //      and tools in the focused category — a small set that cannot blanket
    //      the screen. Only node circles, not rendered labels, are therefore
    //      required to be non-overlapping.
    //
    // We assert both halves of that contract across SE (~320), iPhone (393),
    // and iPad (~744) widths on the full sample seed.

    @Test func sampleSeedCirclesDoNotOverlapAtSECompactWidth() {
        assertCirclesDoNotOverlap(width: 320, height: 568)
    }

    @Test func sampleSeedCirclesDoNotOverlapAtRegularIPhoneWidth() {
        assertCirclesDoNotOverlap(width: 393, height: 852)
    }

    @Test func sampleSeedCirclesDoNotOverlapAtIPadWidth() {
        assertCirclesDoNotOverlap(width: 744, height: 1133)
    }

    @Test func nonFocusedToolLabelsAreCulledAtSECompactWidth() {
        assertNonFocusedToolLabelsAreCulled(width: 320, height: 568)
    }

    @Test func nonFocusedToolLabelsAreCulledAtRegularIPhoneWidth() {
        assertNonFocusedToolLabelsAreCulled(width: 393, height: 852)
    }

    @Test func nonFocusedToolLabelsAreCulledAtIPadWidth() {
        assertNonFocusedToolLabelsAreCulled(width: 744, height: 1133)
    }

    @Test func focusedCategoryAndSelectedToolKeepTheirLabels() {
        let planets = PlanetData.makePlanets(
            categories: UniverseSeed.categories,
            tools: UniverseSeed.tools
        )
        let layout = UniverseGraphLayout.make(
            planets: planets,
            mode: .toolSelected(.analytics, "posthog"),
            size: CGSize(width: 393, height: 852)
        )

        // Core + every category node always keep their label.
        for node in layout.nodes where node.kind != .tool {
            #expect(node.showsLabel, "\(node.id) should keep its label")
        }
        // The selected tool and its (focused-category) siblings keep labels.
        let posthog = layout.nodes.first { $0.id == "tool:posthog" }
        #expect(posthog?.showsLabel == true)
        for node in layout.nodes where node.kind == .tool && node.category == .analytics {
            #expect(node.showsLabel, "context tool \(node.id) should keep its label")
        }
        // A tool in an unfocused category is culled.
        let unfocused = layout.nodes.first { $0.kind == .tool && $0.category != .analytics }
        #expect(unfocused?.showsLabel == false)
    }

    private func sampleSeedLayout(width: CGFloat, height: CGFloat) -> UniverseGraphLayoutResult {
        let planets = PlanetData.makePlanets(
            categories: UniverseSeed.categories,
            tools: UniverseSeed.tools
        )
        return UniverseGraphLayout.make(
            planets: planets,
            mode: .overview,
            size: CGSize(width: width, height: height)
        )
    }

    private func assertCirclesDoNotOverlap(width: CGFloat, height: CGFloat) {
        let nodes = sampleSeedLayout(width: width, height: height).nodes
        for i in nodes.indices {
            for j in nodes.indices where j > i {
                let distance = hypot(
                    nodes[i].position.x - nodes[j].position.x,
                    nodes[i].position.y - nodes[j].position.y
                )
                let minimum = nodes[i].radius + nodes[j].radius
                #expect(
                    distance >= minimum,
                    "Circles overlap at width \(width): \(nodes[i].id) vs \(nodes[j].id) — distance=\(distance), min=\(minimum)"
                )
            }
        }
    }

    private func assertNonFocusedToolLabelsAreCulled(width: CGFloat, height: CGFloat) {
        let nodes = sampleSeedLayout(width: width, height: height).nodes
        // In overview no tool is selected and the focused category is .core, so
        // every tool outside the core category must have its label culled.
        for node in nodes where node.kind == .tool && !node.isSelected && !node.isContext {
            #expect(
                !node.showsLabel,
                "Non-focused tool label not culled at width \(width): \(node.id)"
            )
        }
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
