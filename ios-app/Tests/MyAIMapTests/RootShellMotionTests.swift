import Testing
import CoreGraphics
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

/// Pure-logic coverage for the add-card ghost-flight gate: it flies only when
/// both anchor frames are present and non-empty.
@Suite("RootShell ghost flight gate")
struct RootShellGhostFlightTests {
    private let source = CGRect(x: 20, y: 400, width: 120, height: 32)
    private let destination = CGRect(x: 240, y: 60, width: 90, height: 36)

    @Test("Flies when both anchors are known")
    func fliesWithBothAnchors() {
        #expect(RootShellMotion.shouldFlyGhost(source: source, destination: destination))
    }

    @Test("Does not fly when an anchor is missing")
    func skipsWhenAnchorMissing() {
        #expect(!RootShellMotion.shouldFlyGhost(source: nil, destination: destination))
        #expect(!RootShellMotion.shouldFlyGhost(source: source, destination: nil))
        #expect(!RootShellMotion.shouldFlyGhost(source: nil, destination: nil))
    }

    @Test("Does not fly when an anchor is empty")
    func skipsWhenAnchorEmpty() {
        #expect(!RootShellMotion.shouldFlyGhost(source: .zero, destination: destination))
        #expect(!RootShellMotion.shouldFlyGhost(source: source, destination: .zero))
    }
}

/// Pure-logic coverage for the card→planet tool-flight land gate: the ghost
/// only seats when an active flight's tool matches the frame the universe
/// published (guards against a stale frame from a previously-selected tool)
/// and both anchors are present and non-empty.
@Suite("RootShell tool-flight land gate")
struct RootShellToolFlightTests {
    private let source = CGRect(x: 20, y: 400, width: 120, height: 32)
    private let target = CGRect(x: 180, y: 300, width: 84, height: 84)

    @Test("Lands when ids match and both anchors are known")
    func landsWhenMatched() {
        #expect(RootShellMotion.toolGhostShouldLand(activeToolID: "cursor", publishedToolID: "cursor", source: source, destination: target))
    }

    @Test("Does not land on a stale frame from another tool")
    func skipsWhenIDMismatch() {
        #expect(!RootShellMotion.toolGhostShouldLand(activeToolID: "cursor", publishedToolID: "linear", source: source, destination: target))
    }

    @Test("Does not land when no flight is active")
    func skipsWhenNoActive() {
        #expect(!RootShellMotion.toolGhostShouldLand(activeToolID: nil, publishedToolID: "cursor", source: source, destination: target))
    }

    @Test("Does not land when an anchor is missing or empty")
    func skipsWhenAnchorMissing() {
        #expect(!RootShellMotion.toolGhostShouldLand(activeToolID: "cursor", publishedToolID: "cursor", source: nil, destination: target))
        #expect(!RootShellMotion.toolGhostShouldLand(activeToolID: "cursor", publishedToolID: "cursor", source: source, destination: .zero))
    }
}

/// Pure-logic coverage for the first-run gate: cold start always lands on the
/// map, and the one-screen onboarding overlay shows only on a true first run.
@Suite("RootShell first-run gate")
struct RootFirstRunTests {
    @Test("Cold start always lands on the map surface")
    func coldStartLandsOnMap() {
        #expect(RootFirstRun.initialSurface(hasSeenOnboarding: false) == .universe)
        #expect(RootFirstRun.initialSurface(hasSeenOnboarding: true) == .universe)
    }

    @Test("Onboarding shows only on a true first run")
    func onboardingShowsOnlyOnFirstRun() {
        #expect(RootFirstRun.showsOnboarding(hasSeenOnboarding: false))
        #expect(!RootFirstRun.showsOnboarding(hasSeenOnboarding: true))
    }
}
