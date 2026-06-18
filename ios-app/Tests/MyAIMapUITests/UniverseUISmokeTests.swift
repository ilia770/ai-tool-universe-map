import XCTest

/// Visual smoke harness. Launches with `-uitestStatic` so the app forces Reduce
/// Motion (no perpetual RealityKit spin/pulse) and can reach quiescence — only
/// then can XCUITest take accessibility snapshots / screenshots reliably. Drives
/// key states by element where possible and saves kept screenshots for human
/// review of QA_REGRESSION_CHECKLIST. Manual-only (not in the default test action).
final class UniverseUISmokeTests: XCTestCase {

    override func setUp() { continueAfterFailure = true }

    @MainActor
    func testCaptureKeyStates() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitestStatic"]
        app.launch()
        wait(2.5)
        snap("01-overview")
        attachText("tree-overview", app.debugDescription)

        // Branch focus via a bottom chip.
        for label in ["Design", "Coding", "Research", "Analytics", "Media", "Infrastructure", "Knowledge", "Distribution"] {
            let chip = app.buttons[label]
            if chip.waitForExistence(timeout: 2), chip.isHittable {
                chip.tap(); wait(1.6); snap("02-branch-\(label)")
                attachText("tree-branch", app.debugDescription)
                break
            }
        }

        // Tool selection: tap a satellite orb (3D hit target), then open its
        // detail via the bottom "Selected tool details" card.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.58, dy: 0.66)).tap()
        wait(1.4); snap("03a-tool-selected")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.773)).tap()
        wait(1.6); snap("03b-detail")
        app.swipeDown(velocity: .fast); wait(0.8)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.30)).tap(); wait(0.8) // reset

        // Input focus (not-black confirmation).
        let field = app.textFields.firstMatch
        if field.waitForExistence(timeout: 3) {
            field.tap(); wait(1.4); snap("04-input-focus")
            // Attachment menu while focused.
            let attach = app.buttons["Attach photo or file"]
            if attach.waitForExistence(timeout: 2) {
                attach.tap(); wait(1.0); snap("05-attach-menu")
                if app.buttons["Files"].waitForExistence(timeout: 2) {
                    app.buttons["Files"].tap(); wait(0.8); snap("06-attached-pill")
                }
            }
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.30)).tap(); wait(0.8)
        }

        // Account sheet.
        let account = app.buttons["Account"]
        if account.waitForExistence(timeout: 3), account.isHittable {
            account.tap(); wait(1.4); snap("07-account")
            app.swipeDown(velocity: .fast); wait(0.8)
        }

        // Rail — press-drag the right edge (best-effort).
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.985, dy: 0.52))
            .press(forDuration: 0.6,
                   thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.985, dy: 0.42)))
        wait(0.6); snap("08-after-rail-drag")
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

    private func attachText(_ name: String, _ text: String) {
        let a = XCTAttachment(string: text)
        a.name = name; a.lifetime = .keepAlways; add(a)
    }
}
