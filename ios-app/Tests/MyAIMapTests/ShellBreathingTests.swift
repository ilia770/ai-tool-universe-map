import Testing
import Foundation
@testable import MyAIMap

@Suite("ShellBreathing — pocket-shell wobble + group sway math")
struct ShellBreathingTests {

    @Test func restsAtNeutralAtTimeZero() {
        // No phase offset: the shell starts exactly at its base size and
        // zero yaw so mounting a pocket never pops.
        #expect(ShellBreathing.scale(time: 0, reduceMotion: false) == 1)
        #expect(ShellBreathing.yaw(time: 0, reduceMotion: false) == 0)
    }

    @Test func scaleStaysWithinAmplitudeBand() {
        let amp = ShellBreathing.scaleAmplitude
        for step in 0...400 {
            let t = Double(step) * 0.1
            let s = ShellBreathing.scale(time: t, reduceMotion: false)
            #expect(s >= 1 - amp - 1e-6)
            #expect(s <= 1 + amp + 1e-6)
        }
    }

    @Test func yawStaysWithinSwayBand() {
        let amp = ShellBreathing.yawAmplitude
        for step in 0...400 {
            let t = Double(step) * 0.1
            let y = ShellBreathing.yaw(time: t, reduceMotion: false)
            #expect(y >= -amp - 1e-6)
            #expect(y <= amp + 1e-6)
        }
    }

    @Test func amplitudeMatchesWebShellWobble() {
        // Web PocketWorldShell breathes ±1.8 %.
        #expect(abs(ShellBreathing.scaleAmplitude - 0.018) < 1e-9)
    }

    @Test func reduceMotionFreezesEverything() {
        for step in 0...50 {
            let t = Double(step) * 0.37
            #expect(ShellBreathing.scale(time: t, reduceMotion: true) == 1)
            #expect(ShellBreathing.yaw(time: t, reduceMotion: true) == 0)
        }
    }

    @Test func scaleActuallyOscillates() {
        // Across a full period the scale must reach both above and below 1,
        // otherwise it isn't breathing.
        var sawAbove = false, sawBelow = false
        for step in 0...400 {
            let s = ShellBreathing.scale(time: Double(step) * 0.1, reduceMotion: false)
            if s > 1.0001 { sawAbove = true }
            if s < 0.9999 { sawBelow = true }
        }
        #expect(sawAbove)
        #expect(sawBelow)
    }
}
