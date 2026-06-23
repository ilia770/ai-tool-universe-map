import Testing
@testable import MyAIMap

@Suite("UniverseMode.steppedBack — 3D step-up navigation")
struct UniverseModeSteppedBackTests {
    @Test func toolStepsToItsSun() {
        #expect(UniverseMode.toolSelected(.coding, "cursor").steppedBack == .branchFocus(.coding))
    }
    @Test func sunStepsToOverview() {
        #expect(UniverseMode.branchFocus(.coding).steppedBack == .overview)
    }
    @Test func overviewStaysOverview() {
        #expect(UniverseMode.overview.steppedBack == .overview)
    }
    @Test func detailStepsToToolSelected() {
        #expect(UniverseMode.detail(.design, "figma").steppedBack == .toolSelected(.design, "figma"))
    }
}
