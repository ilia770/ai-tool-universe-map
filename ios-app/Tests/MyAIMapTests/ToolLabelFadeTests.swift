import Testing
@testable import MyAIMap

@Suite("ToolLabelFade — distance-fade curve for pocketed tool labels")
struct ToolLabelFadeTests {

    @Test func fullyOpaqueWhenClose() {
        #expect(ToolLabelFade.opacity(distance: 0) == 1)
        #expect(ToolLabelFade.opacity(distance: ToolLabelFade.nearDistance) == 1)
    }

    @Test func fullyTransparentWhenFar() {
        #expect(ToolLabelFade.opacity(distance: ToolLabelFade.farDistance) == 0)
        #expect(ToolLabelFade.opacity(distance: ToolLabelFade.farDistance + 50) == 0)
    }

    @Test func fadesMonotonicallyBetween() {
        var previous = ToolLabelFade.opacity(distance: ToolLabelFade.nearDistance)
        var step = ToolLabelFade.nearDistance
        while step <= ToolLabelFade.farDistance {
            let here = ToolLabelFade.opacity(distance: step)
            #expect(here <= previous + 1e-6)
            previous = here
            step += 0.5
        }
    }

    @Test func alwaysUnitClamped() {
        for d in stride(from: Float(-5), through: 100, by: 0.5) {
            let o = ToolLabelFade.opacity(distance: d)
            #expect(o >= 0)
            #expect(o <= 1)
        }
    }

    @Test func midpointIsPartial() {
        let mid = (ToolLabelFade.nearDistance + ToolLabelFade.farDistance) / 2
        let o = ToolLabelFade.opacity(distance: mid)
        #expect(o > 0)
        #expect(o < 1)
    }
}
