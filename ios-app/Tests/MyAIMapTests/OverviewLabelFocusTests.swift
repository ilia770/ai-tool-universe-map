// ios-app/Tests/MyAIMapTests/OverviewLabelFocusTests.swift
import Testing
import CoreGraphics
@testable import MyAIMap

@Suite("OverviewLabelFocus — only centered sun speaks")
struct OverviewLabelFocusTests {
    @Test func picksNearestToCenter() {
        let center = CGPoint(x: 200, y: 200)
        let candidates: [(id: ToolCategoryId, point: CGPoint)] = [
            (.coding, CGPoint(x: 210, y: 205)),
            (.design, CGPoint(x: 380, y: 90)),
        ]
        #expect(OverviewLabelFocus.centeredSunID(candidates, screenCenter: center) == .coding)
    }
    @Test func emptyReturnsNil() {
        #expect(OverviewLabelFocus.centeredSunID([], screenCenter: .zero) == nil)
    }
}
