import Testing
@testable import MyAIMap

@Suite("UniverseMotion — pure motion math")
struct UniverseMotionTests {

    // MARK: — smoothing(k:dt:)

    @Test func smoothingIsUnitClamped() {
        // Various k and dt values must stay in [0, 1]
        let pairs: [(Float, Float)] = [
            (1, 0), (1, 0.016), (1, 1), (10, 0.016), (20, 0.016), (100, 1)
        ]
        for (k, dt) in pairs {
            let s = UniverseMotion.smoothing(k: k, dt: dt)
            #expect(s >= 0)
            #expect(s <= 1)
        }
    }

    @Test func smoothingIncreasesWithDt() {
        let k: Float = 8
        let s1 = UniverseMotion.smoothing(k: k, dt: 0.016)
        let s2 = UniverseMotion.smoothing(k: k, dt: 0.033)
        let s3 = UniverseMotion.smoothing(k: k, dt: 0.1)
        #expect(s1 < s2)
        #expect(s2 < s3)
    }

    @Test func smoothingIncreasesWithK() {
        let dt: Float = 0.016
        let s1 = UniverseMotion.smoothing(k: 4,  dt: dt)
        let s2 = UniverseMotion.smoothing(k: 8,  dt: dt)
        let s3 = UniverseMotion.smoothing(k: 16, dt: dt)
        #expect(s1 < s2)
        #expect(s2 < s3)
    }

    @Test func smoothingApproachesOneAsDtGrowsLarge() {
        // dt = 1000 s → exp(-k·dt) ≈ 0
        let s = UniverseMotion.smoothing(k: 8, dt: 1_000)
        #expect(s > 0.9999)
    }

    // MARK: — Frame-rate independence

    /// Composing two dt/2 steps on an exponential-decay residual must equal
    /// one full dt step within a tight epsilon.
    ///
    /// Analytic property: residual after one step = exp(−k·dt).
    /// Two half-steps: exp(−k·dt/2)² = exp(−k·dt). So the residual is
    /// identical — the two approaches must agree to floating-point precision.
    @Test func smoothingIsFrameRateIndependent() {
        let k: Float = 8

        // 60 Hz full step
        let dt60: Float = 1.0 / 60
        // 120 Hz two half-steps
        let dt120: Float = 1.0 / 120

        let target: Float = 1.0

        // Residual after one 60 Hz step
        var val60: Float = 0
        let alpha60 = UniverseMotion.smoothing(k: k, dt: dt60)
        val60 = UniverseMotion.lerp(val60, target, alpha60)
        let residual60 = target - val60

        // Residual after two 120 Hz steps
        var val120: Float = 0
        let alpha120 = UniverseMotion.smoothing(k: k, dt: dt120)
        val120 = UniverseMotion.lerp(val120, target, alpha120)
        val120 = UniverseMotion.lerp(val120, target, alpha120)
        let residual120 = target - val120

        // Both should approximate exp(-k*dt60) — check they agree closely
        #expect(abs(residual60 - residual120) < 1e-5)

        // Also verify naive constant-lerp would NOT satisfy the same property
        // (a naive lerp of 0.5 per half-step gives residual 0.25, vs 1-step 0.5)
        let naiveAlpha: Float = 0.5
        var naiveTwo: Float = 0
        naiveTwo = UniverseMotion.lerp(naiveTwo, target, naiveAlpha)
        naiveTwo = UniverseMotion.lerp(naiveTwo, target, naiveAlpha)
        let naiveResidualTwo = target - naiveTwo   // 0.25
        let naiveResidualOne = target - naiveAlpha // 0.5 (one step from 0)
        // Naive two-step residual is NOT equal to naive one-step residual
        #expect(abs(naiveResidualTwo - naiveResidualOne) > 0.1)
    }

    // MARK: — smoothing with reduceMotion flag

    @Test func smoothingSnapContractWhenReduceMotion() {
        // Regardless of k / dt, the RM-aware overload returns exactly 1
        let s = UniverseMotion.smoothing(k: 8, dt: 0.016, reduceMotion: true)
        #expect(s == 1.0)
    }

    @Test func smoothingNormalWhenReduceMotionFalse() {
        let s = UniverseMotion.smoothing(k: 8, dt: 0.016, reduceMotion: false)
        let expected = UniverseMotion.smoothing(k: 8, dt: 0.016)
        #expect(s == expected)
    }

    // MARK: — easeOutExpo

    @Test func easeOutExpoBoundaries() {
        #expect(UniverseMotion.easeOutExpo(0) == 0)
        #expect(UniverseMotion.easeOutExpo(1) == 1)
    }

    @Test func easeOutExpoIsMonotonic() {
        var prev = UniverseMotion.easeOutExpo(0)
        var x: Float = 0.05
        while x <= 1 {
            let here = UniverseMotion.easeOutExpo(x)
            #expect(here >= prev - 1e-6)
            prev = here
            x += 0.05
        }
    }

    @Test func easeOutExpoIsFrontLoaded() {
        // At the midpoint, the value should exceed 0.5 (most motion done early)
        let mid = UniverseMotion.easeOutExpo(0.5)
        #expect(mid > 0.5)
    }

    // MARK: — pulse

    @Test func pulseStaysWithinAmplitude() {
        let amplitude: Float = 0.05
        let period: Float = 1.4
        var t: Float = 0
        while t < period * 2 {
            let v = UniverseMotion.pulse(time: t, amplitude: amplitude, period: period, reduceMotion: false)
            #expect(v >= 1 - amplitude - 1e-6)
            #expect(v <= 1 + amplitude + 1e-6)
            t += 0.01
        }
    }

    @Test func pulseReturnsOneWhenReduceMotion() {
        let v = UniverseMotion.pulse(time: 0.7, amplitude: 0.05, period: 1.4, reduceMotion: true)
        #expect(v == 1.0)
    }

    // MARK: — transition (RM gate via BrandMotion)

    @Test func transitionCollapseViaReduceMotion() {
        // BrandMotion.resolved with reduceMotion=true returns .linear(duration:0.001).
        // We can't introspect an Animation directly, but we can assert
        // that the two variants are not equal (one is spring, one is linear).
        let normal = UniverseMotion.transition(reduceMotion: false)
        let reduced = UniverseMotion.transition(reduceMotion: true)
        // Both are valid Animations; their inequality confirms RM path differs.
        #expect(normal != reduced)
    }
}
