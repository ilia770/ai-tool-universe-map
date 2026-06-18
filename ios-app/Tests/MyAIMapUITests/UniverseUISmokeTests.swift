import XCTest

/// Visual smoke via PURE coordinate taps. This app runs a continuous RealityKit
/// render loop (frameloop .always), which keeps the main thread busy so XCUITest
/// accessibility snapshots (element queries / debugDescription) time out ("main
/// thread busy for 30s"). Coordinate taps + XCUIScreen screenshots do NOT need a
/// snapshot, so they work. Coordinates are normalized from observed control rects
/// (iPhone 17, ~402x874 pt). Each state is captured then reset to overview by
/// tapping empty space (the 3D scene's empty-tap handler).
final class UniverseUISmokeTests: XCTestCase {

    override func setUp() { continueAfterFailure = true }

    @MainActor
    func testCaptureKeyStates() {
        let app = XCUIApplication()
        app.launch()
        wait(3.0)
        snap("01-overview")

        // Account sheet (top-right button ~ (0.903, 0.110)).
        tap(app, 0.903, 0.110); wait(1.6); snap("02-account")
        app.swipeDown(velocity: .fast); wait(1.2)

        // Category branch focus — Design chip center ~ (0.236, 0.922) (from rect).
        tap(app, 0.236, 0.922); wait(2.0); snap("03-branch")

        // Detail — tap the bottom selection card (~ (0.45, 0.80)) while branched.
        tap(app, 0.45, 0.80); wait(1.6); snap("04-after-cardtap")
        app.swipeDown(velocity: .fast); wait(1.0)
        resetToOverview(app)

        // Input focus — composer field center ~ (0.49, 0.919).
        tap(app, 0.49, 0.919); wait(1.6); snap("05-input-focus")
        resetToOverview(app)

        // Attachment menu — paperclip ~ (0.097, 0.919). Focus first, then tap clip.
        tap(app, 0.49, 0.919); wait(1.0)
        tap(app, 0.097, 0.919); wait(1.2); snap("06-attach-menu")
        resetToOverview(app)

        // Rail — press-drag the right edge (best-effort, can't snap mid-gesture).
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.985, dy: 0.52))
            .press(forDuration: 0.6,
                   thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.985, dy: 0.42)))
        wait(0.6); snap("07-after-rail-drag")
    }

    private func resetToOverview(_ app: XCUIApplication) {
        // Tap empty sky to dismiss chat/keyboard and recenter.
        tap(app, 0.5, 0.30); wait(1.0)
    }

    private func tap(_ app: XCUIApplication, _ dx: CGFloat, _ dy: CGFloat) {
        app.coordinate(withNormalizedOffset: CGVector(dx: dx, dy: dy)).tap()
    }

    private func wait(_ seconds: TimeInterval) {
        let exp = expectation(description: "wait")
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { exp.fulfill() }
        wait(for: [exp], timeout: seconds + 2)
    }

    private func snap(_ name: String) {
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        a.name = name; a.lifetime = .keepAlways; add(a)
    }
}
