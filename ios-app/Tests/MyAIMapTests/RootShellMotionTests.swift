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

@Suite("RootShell navigation policy")
struct RootShellNavigationTests {
    @Test("Starts on the map surface")
    func startsOnMap() {
        #expect(RootShellNavigation.initialSurface == .universe)
    }

    @Test("Map route stays available for empty and populated universes")
    func mapRouteAlwaysAvailable() {
        #expect(RootShellNavigation.canOpenMap(toolCount: 0))
        #expect(RootShellNavigation.canOpenMap(toolCount: 1))
        #expect(RootShellNavigation.canOpenMap(toolCount: 3))
    }

    @Test("Map accessibility label explains empty state")
    func mapAccessibilityLabel() {
        #expect(RootShellNavigation.mapAccessibilityLabel(toolCount: 0) == "Open universe map, empty")
        #expect(RootShellNavigation.mapAccessibilityLabel(toolCount: 4) == "Open universe map, 4 tools")
    }
}
