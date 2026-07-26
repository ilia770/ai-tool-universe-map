import Testing
@testable import MyAIMap

@Suite("Map renderer release boundary")
struct RendererBoundaryTests {
    @Test func releaseRendererIsConstellation2D() {
        #expect(MapRendererKind.release == .constellation2D)
    }
}
