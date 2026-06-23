// ios-app/Tests/MyAIMapTests/SpatialChromeTests.swift
import Testing
@testable import MyAIMap

@Suite("SpatialChrome — 3D hides map chrome")
struct SpatialChromeTests {
    @Test func chromeShowsInGraph2DOverview() {
        #expect(SpatialChrome.showsMapChrome(renderMode: .graph2D, mode: .overview, isUniverseEmpty: false) == true)
    }

    @Test func chromeHiddenInSpatial3D() {
        #expect(SpatialChrome.showsMapChrome(renderMode: .spatial3D, mode: .overview, isUniverseEmpty: false) == false)
    }

    @Test func chromeHiddenInDetailOrChatEvenIn2D() {
        #expect(SpatialChrome.showsMapChrome(renderMode: .graph2D, mode: .detail(.coding, "x"), isUniverseEmpty: false) == false)
        #expect(SpatialChrome.showsMapChrome(renderMode: .graph2D, mode: .chatOpen(nil, nil), isUniverseEmpty: false) == false)
    }

    @Test func chromeHiddenWhenEmpty() {
        #expect(SpatialChrome.showsMapChrome(renderMode: .graph2D, mode: .overview, isUniverseEmpty: true) == false)
    }
}
