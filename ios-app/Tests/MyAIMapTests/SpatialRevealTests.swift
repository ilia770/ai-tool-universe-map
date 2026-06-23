// ios-app/Tests/MyAIMapTests/SpatialRevealTests.swift
import Testing
@testable import MyAIMap

@Suite("SpatialReveal — selected-tool card visibility")
struct SpatialRevealTests {
    @Test func showsOnlyForToolSelectedIn3D() {
        #expect(SpatialReveal.showsToolCard(renderMode: .spatial3D, mode: .toolSelected(.coding, "cursor")) == true)
    }
    @Test func hiddenInOverviewAndSunFocus() {
        #expect(SpatialReveal.showsToolCard(renderMode: .spatial3D, mode: .overview) == false)
        #expect(SpatialReveal.showsToolCard(renderMode: .spatial3D, mode: .branchFocus(.coding)) == false)
    }
    @Test func hiddenIn2D() {
        #expect(SpatialReveal.showsToolCard(renderMode: .graph2D, mode: .toolSelected(.coding, "cursor")) == false)
    }
}
