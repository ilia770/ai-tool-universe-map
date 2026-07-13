// ios-app/Tests/MyAIMapTests/SpatialRevealTests.swift
import Testing
@testable import MyAIMap

@Suite("SpatialReveal — selected-tool card visibility")
struct SpatialRevealTests {
    @Test func showsOnlyForToolSelectedIn3D() {
        #expect(SpatialReveal.showsToolCard(mode: .toolSelected(.coding, "cursor")) == true)
    }
    @Test func hiddenInOverviewAndSunFocus() {
        #expect(SpatialReveal.showsToolCard(mode: .overview) == false)
        #expect(SpatialReveal.showsToolCard(mode: .branchFocus(.coding)) == false)
    }
    @Test func hiddenIn2D() {
    }
}
