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
        app.launchArguments = ["-uitestStatic", "-uitestSampleUniverse"]
        app.launch()
        wait(2.5)
        let composer = app.textFields["chat-composer-field"]
        XCTAssertTrue(composer.waitForExistence(timeout: 5), "Chat-first launch should show the composer")
        snap("01-chat")
        attachText("tree-chat", app.debugDescription)

        let openUniverse = app.buttons["RootShell.ShowUniverse"]
        XCTAssertTrue(openUniverse.waitForExistence(timeout: 4), "Chat-first root should expose the Map route")
        if openUniverse.isHittable {
            openUniverse.tap()
        }
        wait(2.0)
        snap("02-overview")
        attachText("tree-overview", app.debugDescription)

        // Branch focus via the 2D graph node accessibility label.
        let analyticsNode = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Category node, Analytics")
        ).firstMatch
        if analyticsNode.waitForExistence(timeout: 4), analyticsNode.isHittable {
            analyticsNode.tap()
            wait(1.6)
            snap("02-branch-Analytics")
            attachText("tree-branch", app.debugDescription)
        }

        // Tool selection: tap a graph tool node, then open its detail card.
        let toolNode = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Tool node,")
        ).firstMatch
        if toolNode.waitForExistence(timeout: 4), toolNode.isHittable {
            toolNode.tap()
        }
        wait(1.4); snap("03a-tool-selected")
        let selectedDetails = app.buttons["Selected planet details"]
        if selectedDetails.waitForExistence(timeout: 3), selectedDetails.isHittable {
            selectedDetails.tap()
        }
        wait(1.6); snap("03b-detail")
        app.swipeDown(velocity: .fast); wait(0.8)
        let coreNode = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Core node,")
        ).firstMatch
        if coreNode.waitForExistence(timeout: 2), coreNode.isHittable {
            coreNode.tap()
        }
        wait(0.8)

        // Rail — press-drag the right edge while the map is active (best-effort).
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.985, dy: 0.52))
            .press(forDuration: 0.6,
                   thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.985, dy: 0.42)))
        wait(0.6); snap("08-after-rail-drag")

        let showChat = app.buttons["RootShell.ShowChat"]
        XCTAssertTrue(showChat.waitForExistence(timeout: 3), "Map route should expose the Chat return control")
        if showChat.isHittable {
            showChat.tap()
        }
        wait(1.2)

        // Account sheet from the chat shell, before keyboard focus can affect idle waits.
        let account = app.buttons["ChatScreen.Account"]
        if account.waitForExistence(timeout: 3), account.isHittable {
            account.tap(); wait(1.4); snap("07-account")
            app.swipeDown(velocity: .fast); wait(0.8)
        }

        // Input focus (not-black confirmation).
        let field = app.textFields["chat-composer-field"]
        if field.waitForExistence(timeout: 3) {
            field.tap(); wait(1.4); snap("04-input-focus")
            // Attachment menu while focused.
            let attach = app.buttons["chat-attach-button"]
            if attach.waitForExistence(timeout: 2) {
                attach.tap(); wait(1.0); snap("05-attach-menu")
                let files = app.buttons["chat-attachment-files"]
                XCTAssertTrue(files.waitForExistence(timeout: 2), "Attachment menu should expose Files")
                if files.isHittable {
                    files.tap(); wait(0.8); snap("06-attached-pill")
                }
            }
        }
    }

    private func wait(_ seconds: TimeInterval) {
        let exp = expectation(description: "wait")
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { exp.fulfill() }
        wait(for: [exp], timeout: seconds + 2)
    }

    @MainActor
    private func snap(_ name: String) {
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        a.name = name; a.lifetime = .keepAlways; add(a)
    }

    private func attachText(_ name: String, _ text: String) {
        let a = XCTAttachment(string: text)
        a.name = name; a.lifetime = .keepAlways; add(a)
    }
}
