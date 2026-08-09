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

        #expect(actualToolIDs == expectedToolIDs)
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
}
