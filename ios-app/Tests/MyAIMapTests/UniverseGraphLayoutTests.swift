import CoreGraphics
import Testing
@testable import MyAIMap

@Suite("UniverseGraphLayout — readable 2D graph")
struct UniverseGraphLayoutTests {

    @Test func overviewShowsCategoriesButHidesTools() {
        let layout = makeLayout() // .overview

        #expect(layout.nodes.contains { $0.id == "category:analytics" })
        #expect(layout.edges.contains { $0.targetID == "category:analytics" })
        // Progressive disclosure: no tool nodes are emitted until a branch is
        // focused, so the overview reads as a clean core + category hub.
        #expect(!layout.nodes.contains { $0.kind == .tool })
    }

    @Test func focusedBranchRevealsItsTools() {
        let layout = makeLayout(mode: .branchFocus(.analytics))

        #expect(layout.nodes.contains { $0.id == "tool:posthog" })
        #expect(layout.edges.contains { $0.targetID == "tool:posthog" })
        // Tools from other categories stay hidden while one branch is focused.
        #expect(!layout.nodes.contains { $0.kind == .tool && $0.category != .analytics })
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

    @Test func graphEdgesAnchorAtNodeBoundaries() {
        let layout = makeLayout(mode: .toolSelected(.analytics, "posthog"))
        let edge = layout.edges.first { $0.targetID == "tool:posthog" }
        let source = layout.nodes.first { $0.id == edge?.sourceID }
        let target = layout.nodes.first { $0.id == edge?.targetID }

        #expect(edge != nil)
        #expect(source != nil)
        #expect(target != nil)
        guard let edge, let source, let target else { return }

        let endpoints = edge.anchoredEndpoints()
        let sourceDistance = hypot(endpoints.source.x - source.position.x, endpoints.source.y - source.position.y)
        let targetDistance = hypot(endpoints.target.x - target.position.x, endpoints.target.y - target.position.y)

        #expect(abs(sourceDistance - (source.radius + 2)) < 0.001)
        #expect(abs(targetDistance - (target.radius + 2)) < 0.001)
        #expect(endpoints.source != source.position)
        #expect(endpoints.target != target.position)
    }

    @Test func twoBranchGraphDoesNotReadAsVerticalStack() {
        let layout = makeTwoBranchLayout()
        let branches = layout.nodes.filter { $0.kind == .category && $0.category != .core }

        #expect(branches.count == 2)
        guard branches.count == 2 else { return }

        let horizontalSpread = abs(branches[0].position.x - branches[1].position.x)
        let verticalSpread = abs(branches[0].position.y - branches[1].position.y)
        #expect(horizontalSpread > verticalSpread, "Two branches should balance horizontally, not stack vertically")
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

    // MARK: - Progressive-disclosure overlap contract (full sample seed)

    // The 2D graph is the DEFAULT renderer, and the full sample seed (~50 tools)
    // cannot pack ~50 nodes + labels into one phone screen without overlap.
    //
    // No-overlap contract (progressive disclosure, matching the 3D scene):
    //   1. The overview emits core + categories only — no tool nodes — so it is
    //      a clean hub-and-spoke that fits one screen.
    //   2. Tool nodes are revealed only for the focused category, a small set
    //      that the collision solver can always keep non-overlapping.
    //   3. Every emitted node *circle* is guaranteed non-overlapping at every
    //      width.
    //
    // We assert this across SE (~320), iPhone (393), and iPad (~744) widths.

    @Test func sampleSeedCirclesDoNotOverlapAtSECompactWidth() {
        assertCirclesDoNotOverlap(width: 320, height: 568)
    }

    @Test func sampleSeedCirclesDoNotOverlapAtRegularIPhoneWidth() {
        assertCirclesDoNotOverlap(width: 393, height: 852)
    }

    @Test func sampleSeedCirclesDoNotOverlapAtIPadWidth() {
        assertCirclesDoNotOverlap(width: 744, height: 1133)
    }

    @Test func overviewEmitsNoToolNodesAtSECompactWidth() {
        assertOverviewEmitsNoToolNodes(width: 320, height: 568)
    }

    @Test func overviewEmitsNoToolNodesAtRegularIPhoneWidth() {
        assertOverviewEmitsNoToolNodes(width: 393, height: 852)
    }

    @Test func overviewEmitsNoToolNodesAtIPadWidth() {
        assertOverviewEmitsNoToolNodes(width: 744, height: 1133)
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
        // Tools in unfocused categories are not emitted at all (progressive
        // disclosure), so there is nothing to label there.
        #expect(!layout.nodes.contains { $0.kind == .tool && $0.category != .analytics })
    }

    @Test func focusedBranchAutoPanKeepsAnalyticsToolTouchable() {
        let viewport = CGSize(width: 402, height: 874)
        for mode in [UniverseMode.branchFocus(.analytics), .toolSelected(.analytics, "posthog")] {
            let layout = makeLayout(mode: mode, size: viewport)
            let focusPan = UniverseGraphViewport.focusPan(
                layout: layout,
                mode: mode,
                viewport: viewport,
                scale: 1
            )
            let pan = UniverseGraphViewport.visiblePan(
                storedPan: .zero,
                focusPan: focusPan,
                layout: layout,
                viewport: viewport,
                scale: 1
            )

            let posthog = layout.nodes.first { $0.id == "tool:posthog" }
            #expect(posthog != nil)
            guard let posthog else { return }

            let frame = UniverseGraphViewport.projectedFrame(
                for: posthog,
                viewport: viewport,
                scale: 1,
                pan: pan
            )
            #expect(frame.minX >= 0, "PostHog should not sit off the left edge after focus pan: \(frame)")
            #expect(frame.maxX <= viewport.width, "PostHog should not sit off the right edge after focus pan: \(frame)")
            #expect(frame.minY >= 0, "PostHog should not sit off the top edge after focus pan: \(frame)")
            #expect(frame.maxY <= viewport.height - 214, "PostHog should stay above the bottom chrome after focus pan: \(frame)")
        }
    }

    @Test func focusedBranchAutoPanKeepsAToolTouchableForEveryCategory() {
        let viewport = CGSize(width: 402, height: 874)
        let topChromeBottom: CGFloat = 196
        let bottomDockTop = viewport.height - 214

        for category in UniverseSeed.categories.map(\.id) where category != .core {
            let layout = makeLayout(mode: .branchFocus(category), size: viewport)
            let focusPan = UniverseGraphViewport.focusPan(
                layout: layout,
                mode: .branchFocus(category),
                viewport: viewport,
                scale: 1
            )
            let pan = UniverseGraphViewport.visiblePan(
                storedPan: .zero,
                focusPan: focusPan,
                layout: layout,
                viewport: viewport,
                scale: 1
            )
            let toolFrames = layout.nodes
                .filter { $0.kind == .tool && $0.category == category }
                .map {
                    UniverseGraphViewport.projectedFrame(
                        for: $0,
                        viewport: viewport,
                        scale: 1,
                        pan: pan
                    )
                }

            #expect(
                toolFrames.contains { frame in
                    frame.minX >= 0
                        && frame.maxX <= viewport.width
                        && frame.minY >= topChromeBottom
                        && frame.maxY <= bottomDockTop
                },
                "\(category.rawValue) should keep at least one focused tool fully tappable; frames=\(toolFrames)"
            )
        }
    }

    @Test func focusedBranchAutoPanKeepsAToolTouchableAtSECompactWidth() {
        // The top-align fallback for tall clusters must still leave at least one
        // focused tool fully inside the tappable band on the smallest phone.
        let viewport = CGSize(width: 320, height: 568)
        let topChromeBottom: CGFloat = 196
        let bottomDockTop = viewport.height - 214

        for category in UniverseSeed.categories.map(\.id) where category != .core {
            let layout = makeLayout(mode: .branchFocus(category), size: viewport)
            let focusPan = UniverseGraphViewport.focusPan(
                layout: layout,
                mode: .branchFocus(category),
                viewport: viewport,
                scale: 1
            )
            let pan = UniverseGraphViewport.visiblePan(
                storedPan: .zero,
                focusPan: focusPan,
                layout: layout,
                viewport: viewport,
                scale: 1
            )
            let toolFrames = layout.nodes
                .filter { $0.kind == .tool && $0.category == category }
                .map {
                    UniverseGraphViewport.projectedFrame(
                        for: $0,
                        viewport: viewport,
                        scale: 1,
                        pan: pan
                    )
                }

            #expect(
                toolFrames.contains { frame in
                    frame.minX >= 0
                        && frame.maxX <= viewport.width
                        && frame.minY >= topChromeBottom
                        && frame.maxY <= bottomDockTop
                },
                "\(category.rawValue) at SE width should keep at least one focused tool fully tappable; frames=\(toolFrames)"
            )
        }
    }

    @Test func coreFocusRevealsOnlyCoreToolsNotOtherBranches() {
        // Guards the progressive-disclosure contract for the core branch: if
        // core is ever focused, only core tools may appear — never a flood of
        // every category's tools (which is what would happen if .overview's
        // focusedCategory == .core leaked into tool emission).
        let layout = makeLayout(mode: .toolSelected(.core, "founder-os"))
        let toolNodes = layout.nodes.filter { $0.kind == .tool }
        #expect(
            toolNodes.allSatisfy { $0.category == .core },
            "core focus should emit only core tools; got \(toolNodes.map { ($0.id, $0.category) })"
        )
    }

    @Test func focusPanRoundTripsStoredPanWithoutDrift() {
        let viewport = CGSize(width: 402, height: 874)
        let mode = UniverseMode.branchFocus(.analytics)
        let layout = makeLayout(mode: mode, size: viewport)
        let focusPan = UniverseGraphViewport.focusPan(
            layout: layout,
            mode: mode,
            viewport: viewport,
            scale: 1
        )
        let clampedVisiblePan = UniverseGraphViewport.visiblePan(
            storedPan: CGSize(width: -900, height: 340),
            focusPan: focusPan,
            layout: layout,
            viewport: viewport,
            scale: 1
        )
        let storedPan = UniverseGraphViewport.storedPan(
            forVisiblePan: clampedVisiblePan,
            focusPan: focusPan,
            layout: layout,
            viewport: viewport,
            scale: 1
        )
        let roundTrippedVisiblePan = UniverseGraphViewport.visiblePan(
            storedPan: storedPan,
            focusPan: focusPan,
            layout: layout,
            viewport: viewport,
            scale: 1
        )

        #expect(abs(roundTrippedVisiblePan.width - clampedVisiblePan.width) < 0.001)
        #expect(abs(roundTrippedVisiblePan.height - clampedVisiblePan.height) < 0.001)
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

    private func assertOverviewEmitsNoToolNodes(width: CGFloat, height: CGFloat) {
        let nodes = sampleSeedLayout(width: width, height: height).nodes
        // Progressive disclosure: the overview is core + categories only. No
        // tool node is emitted until a branch is focused, so the full ~50-tool
        // seed can never blanket the screen.
        let toolNodes = nodes.filter { $0.kind == .tool }
        #expect(
            toolNodes.isEmpty,
            "Overview should emit no tool nodes at width \(width); got \(toolNodes.map(\.id))"
        )
    }

    private func makeLayout(
        mode: UniverseMode = .overview,
        size: CGSize = CGSize(width: 393, height: 852)
    ) -> UniverseGraphLayoutResult {
        let planets = PlanetData.makePlanets(
            categories: UniverseSeed.categories,
            tools: UniverseSeed.tools
        )
        return UniverseGraphLayout.make(
            planets: planets,
            mode: mode,
            size: size
        )
    }

    private func makeTwoBranchLayout() -> UniverseGraphLayoutResult {
        let included: Set<ToolCategoryId> = [.core, .design, .analytics]
        let categories = UniverseSeed.categories.filter { included.contains($0.id) }
        let tools = UniverseSeed.tools.filter { included.contains($0.category) }
        let planets = PlanetData.makePlanets(categories: categories, tools: tools)
        return UniverseGraphLayout.make(
            planets: planets,
            mode: .overview,
            size: CGSize(width: 393, height: 852)
        )
    }
}
