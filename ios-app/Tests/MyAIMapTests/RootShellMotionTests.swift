import Testing
@testable import MyAIMap

/// Pure-logic coverage for the Map badge pop rule: it must fire on increments
/// only, staying silent on decrements and no-op changes.
@Suite("RootShell badge pop rule")
struct RootShellMotionTests {
    @Test("Pops when the tool count increases")
    func popsOnIncrease() {
        #expect(RootShellMotion.badgeShouldPop(from: 0, to: 1))
        #expect(RootShellMotion.badgeShouldPop(from: 2, to: 5))
    }

    @Test("Stays silent when the count is unchanged")
    func silentWhenUnchanged() {
        #expect(!RootShellMotion.badgeShouldPop(from: 3, to: 3))
    }

    @Test("Stays silent when the count decreases")
    func silentOnDecrease() {
        #expect(!RootShellMotion.badgeShouldPop(from: 4, to: 2))
    }
}
