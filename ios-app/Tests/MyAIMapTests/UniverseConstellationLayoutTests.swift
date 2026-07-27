import CoreGraphics
import Testing
@testable import MyAIMap

@Suite("UniverseConstellationLayout")
struct UniverseConstellationLayoutTests {
    private let phone = CGSize(width: 393, height: 852)

    @Test func overviewExposesBranchesButNotCoreAsCategoryButtons() {
        let planets = PlanetData.makePlanets(categories: UniverseSeed.categories, tools: UniverseSeed.tools)
        let layout = UniverseConstellationLayout.make(planets: planets, mode: .overview, size: phone)

        #expect(layout.corePoint != nil)
        #expect(layout.categoryNodes.contains { $0.categoryID == .coding })
        #expect(!layout.categoryNodes.contains { $0.categoryID == .core })
        #expect(layout.toolNodes.isEmpty)
    }

    @Test func overviewCategoryFootprintsDoNotOverlapOnPhone() {
        let planets = PlanetData.makePlanets(categories: UniverseSeed.categories, tools: UniverseSeed.tools)
        let nodes = UniverseConstellationLayout.make(planets: planets, mode: .overview, size: phone).categoryNodes

        for leftIndex in nodes.indices {
            for rightIndex in nodes.indices where rightIndex > leftIndex {
                let left = nodes[leftIndex]
                let right = nodes[rightIndex]
                let leftFrames = UniverseConstellationLayout.categoryVisualFrames(for: left)
                let rightFrames = UniverseConstellationLayout.categoryVisualFrames(for: right)

                for leftFrame in leftFrames {
                    for rightFrame in rightFrames {
                        #expect(!leftFrame.intersects(rightFrame))
                    }
                }
            }
        }
    }

    @Test func overviewLabelsStayInsideThePhoneCanvas() {
        let planets = PlanetData.makePlanets(categories: UniverseSeed.categories, tools: UniverseSeed.tools)
        let nodes = UniverseConstellationLayout.make(planets: planets, mode: .overview, size: phone).categoryNodes
        let canvas = CGRect(origin: .zero, size: phone)

        for node in nodes {
            #expect(canvas.contains(UniverseConstellationLayout.categoryVisualFrame(for: node)))
        }
    }

    @Test func branchFocusExposesOnlyFocusedBranchTools() {
        let planets = PlanetData.makePlanets(categories: UniverseSeed.categories, tools: UniverseSeed.tools)
        let layout = UniverseConstellationLayout.make(planets: planets, mode: .branchFocus(.coding), size: phone)

        let expectedToolIDs = Set(UniverseSeed.tools(in: .coding).map(\.id))
        let actualToolIDs = Set(layout.toolNodes.map(\.toolID))

        #expect(!actualToolIDs.isEmpty)
        #expect(actualToolIDs.isSubset(of: expectedToolIDs))
        #expect(layout.toolNodes.allSatisfy { $0.categoryID == .coding })
        #expect(layout.toolNodes.count <= UniverseConstellationLayout.maximumVisibleToolCount)
        #expect(layout.categoryNodes.contains { $0.categoryID == .coding && $0.isFocused })
        #expect(!layout.categoryNodes.contains { $0.categoryID == .core && !$0.isContext })
    }

    @Test func denseBranchToolLabelsDoNotOverlapOrLeaveTheCanvas() {
        let planets = PlanetData.makePlanets(categories: UniverseSeed.categories, tools: UniverseSeed.tools)
        let layout = UniverseConstellationLayout.make(planets: planets, mode: .branchFocus(.coding), size: phone)
        let frames = layout.toolNodes.map(UniverseConstellationLayout.toolVisualFrame)
        let canvas = CGRect(origin: .zero, size: phone)

        for frame in frames {
            #expect(canvas.contains(frame))
        }
        for leftIndex in frames.indices {
            for rightIndex in frames.indices where rightIndex > leftIndex {
                #expect(!frames[leftIndex].intersects(frames[rightIndex]))
            }
        }
        #expect(layout.categoryNodes.filter(\.isContext).isEmpty)
    }

    @Test func selectedToolIsMarkedAndSizedUp() {
        let planets = PlanetData.makePlanets(categories: UniverseSeed.categories, tools: UniverseSeed.tools)
        let layout = UniverseConstellationLayout.make(
            planets: planets,
            mode: .toolSelected(.coding, "lovable"),
            size: phone
        )

        let selected = layout.toolNodes.first { $0.toolID == "lovable" }
        let unselected = layout.toolNodes.first { $0.toolID != "lovable" }

        #expect(selected?.isSelected == true)
        #expect((selected?.diameter ?? 0) > (unselected?.diameter ?? 999))
    }

    @Test func focusedBranchKeepsAtLeastOneToolInSmokeSafeBand() throws {
        let planets = PlanetData.makePlanets(categories: UniverseSeed.categories, tools: UniverseSeed.tools)
        let layout = UniverseConstellationLayout.make(planets: planets, mode: .branchFocus(.coding), size: phone)
        let firstCodingTool = try #require(layout.toolNodes.first { $0.categoryID == .coding })

        let hitFrame = CGRect(
            x: firstCodingTool.point.x - 43,
            y: firstCodingTool.point.y - 43,
            width: 86,
            height: 86
        )

        #expect(hitFrame.minX >= 0)
        #expect(hitFrame.maxX <= phone.width)
        #expect(hitFrame.minY >= 196)
        #expect(hitFrame.maxY <= phone.height - 214)
    }

    @Test func largeCatalogsPageRenderedNodesWithoutDroppingAnyTool() throws {
        let sizes = [
            CGSize(width: 320, height: 667),
            CGSize(width: 393, height: 852),
            CGSize(width: 1024, height: 768),
        ]

        for toolCount in [100, 500, 1_000] {
            let planets = PlanetData.makePlanets(
                categories: [UniverseSeed.category(.coding)],
                tools: generatedTools(count: toolCount)
            )

            for size in sizes {
                let firstPage = UniverseConstellationLayout.make(
                    planets: planets,
                    mode: .branchFocus(.coding),
                    size: size
                )
                let pageCount = try #require(firstPage.toolPage?.count)
                var renderedToolIDs = Set<String>()

                for pageIndex in 0..<pageCount {
                    let layout = UniverseConstellationLayout.make(
                        planets: planets,
                        mode: .branchFocus(.coding),
                        size: size,
                        requestedToolPageIndex: pageIndex
                    )

                    #expect(layout.toolNodes.count <= UniverseConstellationLayout.maximumVisibleToolCount)
                    #expect(layout.edges.count == layout.toolNodes.count)
                    #expect(layout.toolPage?.index == pageIndex)
                    assertUniqueIDs(layout.categoryNodes.map(\.id), nodeType: "category")
                    assertUniqueIDs(layout.toolNodes.map(\.id), nodeType: "tool")
                    assertAllPointsAreInside(layout, size: size)
                    assertToolFramesDoNotOverlap(layout.toolNodes)
                    renderedToolIDs.formUnion(layout.toolNodes.map(\.toolID))
                }

                #expect(renderedToolIDs == Set(generatedTools(count: toolCount).map(\.id)))
            }
        }
    }

    @Test func selectingAnOffPageToolRendersItsOwningPage() throws {
        let tools = generatedTools(count: CatalogDocument.maximumToolCount)
        let planets = PlanetData.makePlanets(categories: [UniverseSeed.category(.coding)], tools: tools)
        let selectedToolIDs = [
            try #require(tools.first?.id),
            tools[tools.count / 2].id,
            try #require(tools.last?.id),
        ]
        let sizes = [
            CGSize(width: 320, height: 667),
            phone,
            CGSize(width: 393, height: 760),
        ]

        for size in sizes {
            for selectedToolID in selectedToolIDs {
                let layout = UniverseConstellationLayout.make(
                    planets: planets,
                    mode: .toolSelected(.coding, selectedToolID),
                    size: size,
                    requestedToolPageIndex: 0
                )

                #expect(layout.toolNodes.count <= UniverseConstellationLayout.maximumVisibleToolCount)
                #expect(layout.toolNodes.contains { $0.toolID == selectedToolID && $0.isSelected })
                assertToolFramesDoNotOverlap(layout.toolNodes)
            }
        }
    }

    private func generatedTools(count: Int) -> [Tool] {
        (0..<count).map { index in
            Tool(
                id: "large-catalog-tool-\(index)",
                name: "Large Catalog Tool \(index)",
                category: .coding,
                summary: "Deterministic large-catalog fixture.",
                stage: .research,
                orbit: .inner,
                angle: Float(index),
                url: nil,
                logoDomain: nil,
                relationIds: [],
                classification: nil
            )
        }
    }

    private func assertUniqueIDs(_ ids: [String], nodeType: String) {
        let duplicates = Dictionary(grouping: ids, by: { $0 })
            .filter { $0.value.count > 1 }
            .map(\.key)
            .sorted()

        #expect(duplicates.isEmpty, "Duplicate \(nodeType) IDs: \(duplicates.joined(separator: ", "))")
    }

    private func assertAllPointsAreInside(
        _ layout: UniverseConstellationLayout.Layout,
        size: CGSize
    ) {
        let safeContent = UniverseConstellationLayout.contentRect(in: size)
        let nodes = layout.categoryNodes.map { (id: $0.id, point: $0.point) }
            + layout.toolNodes.map { (id: $0.id, point: $0.point) }

        for node in nodes {
            #expect(node.point.x >= 0 && node.point.x <= size.width, "Out-of-bounds x point \(node.point) for \(node.id)")
            #expect(node.point.y >= 0 && node.point.y <= size.height, "Out-of-bounds y point \(node.point) for \(node.id)")
            #expect(safeContent.contains(node.point), "Point \(node.point) for \(node.id) escapes safe inset \(safeContent)")
        }
    }

    private func assertToolFramesDoNotOverlap(_ nodes: [UniverseConstellationLayout.ToolNode]) {
        let frames = nodes.map(UniverseConstellationLayout.toolVisualFrame)
        for leftIndex in frames.indices {
            for rightIndex in frames.indices where rightIndex > leftIndex {
                #expect(!frames[leftIndex].intersects(frames[rightIndex]))
            }
        }
    }
}
