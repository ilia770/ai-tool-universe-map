import Testing
@testable import MyAIMap

@Suite("SunLightIntensity — focus-aware sun lighting")
struct SunLightIntensityTests {
    @Test func focusedSunIsBrightestInBranchFocus() {
        let focused = SunLightIntensity.intensity(for: .branchFocus(.coding), isFocused: true)
        let other = SunLightIntensity.intensity(for: .branchFocus(.coding), isFocused: false)
        #expect(focused > other)
    }

    @Test func overviewIsSoftAndUniform() {
        let a = SunLightIntensity.intensity(for: .overview, isFocused: true)
        let b = SunLightIntensity.intensity(for: .overview, isFocused: false)
        #expect(a == b)
        #expect(a < SunLightIntensity.intensity(for: .branchFocus(.coding), isFocused: true))
    }

    @Test func detailRecedesNonFocused() {
        let other = SunLightIntensity.intensity(for: .detail(.coding, "x"), isFocused: false)
        #expect(other < SunLightIntensity.intensity(for: .branchFocus(.coding), isFocused: false))
    }
}
