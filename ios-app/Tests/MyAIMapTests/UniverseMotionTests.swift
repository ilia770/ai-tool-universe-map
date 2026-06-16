import Testing
@testable import MyAIMap

@Suite("UniverseMotion")
struct UniverseMotionTests {
    @Test func easeOutExpoEndpoints() {
        #expect(abs(UniverseMotion.easeOutExpo(0) - 0) < 1e-4)
        #expect(abs(UniverseMotion.easeOutExpo(1) - 1) < 1e-3)
    }
    @Test func easeOutExpoMonotonic() {
        #expect(UniverseMotion.easeOutExpo(0.25) < UniverseMotion.easeOutExpo(0.75))
    }
    @Test func frameRateIndependentApproach() {
        // one 0.2s step vs two 0.1s steps land within tolerance
        let k: Float = 8
        let one = UniverseMotion.approach(0, 1, dt: 0.2, k: k, reduceMotion: false)
        var two: Float = 0
        two = UniverseMotion.approach(two, 1, dt: 0.1, k: k, reduceMotion: false)
        two = UniverseMotion.approach(two, 1, dt: 0.1, k: k, reduceMotion: false)
        #expect(abs(one - two) < 0.03)
    }
    @Test func reduceMotionSnaps() {
        #expect(UniverseMotion.approach(0, 1, dt: 0.016, k: 8, reduceMotion: true) == 1)
    }
}
