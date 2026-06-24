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
        let showChatInitial = app.buttons["RootShell.ShowChat"]
        XCTAssertTrue(showChatInitial.waitForExistence(timeout: 5), "Map-first launch should expose the Ask AI route")
        snap("01-map-first")
        attachText("tree-map-first", app.debugDescription)

        if showChatInitial.isHittable {
            showChatInitial.tap()
        }
        wait(1.2)
        let composer = app.textFields["chat-composer-field"]
        XCTAssertTrue(composer.waitForExistence(timeout: 5), "Ask AI route should show the composer")
        snap("01-chat")
        attachText("tree-chat", app.debugDescription)

        let openUniverse = app.buttons["RootShell.ShowUniverse"]
        XCTAssertTrue(openUniverse.waitForExistence(timeout: 4), "Chat root should expose the Map route")
        if openUniverse.isHittable {
            openUniverse.tap()
        }
        wait(2.0)
        snap("02-overview")
        attachText("tree-overview", app.debugDescription)

        // Branch focus via the 2D graph node accessibility label.
        let analyticsNode = app.buttons["GraphNode.Category.analytics"]
        XCTAssertTrue(analyticsNode.waitForExistence(timeout: 4), "2D graph should expose the Analytics category node")
        tapNode(analyticsNode, name: "Analytics category node")
        wait(1.6)
        snap("02-branch-Analytics")
        attachText("tree-branch", app.debugDescription)

        let selectedBranch = app.staticTexts["PlanetInfoCard.SelectedBranch"].firstMatch
        XCTAssertTrue(selectedBranch.waitForExistence(timeout: 3), "Branch card should expose a stable selected branch label")
        XCTAssertTrue(
            selectedBranch.label.contains("Analytics"),
            "Branch card should match the tapped Analytics node; got \(selectedBranch.label)"
        )

        // Tool selection: tap a graph tool node, then open its detail card.
        let preferredToolNode = app.buttons["GraphNode.Tool.posthog"]
        let toolNode = preferredToolNode.waitForExistence(timeout: 4) && preferredToolNode.isHittable
            ? preferredToolNode
            : firstHittableButton(app, identifierPrefix: "GraphNode.Tool.", timeout: 8)
        if toolNode == nil {
            attachText("tree-no-hittable-tool-node", app.debugDescription)
        }
        XCTAssertNotNil(toolNode, "Analytics branch should expose at least one hittable tool node")
        guard let toolNode else { return }
        tapNode(toolNode, name: "tool node")
        wait(1.8); snap("03a-tool-selected")
        let selectedDetails = app.descendants(matching: .any)["PlanetInfoCard.SelectedDetails"].firstMatch
        if !selectedDetails.waitForExistence(timeout: 6) {
            attachText("tree-tool-selected-missing-details", app.debugDescription)
            tapNode(toolNode, name: "tool node retry")
            wait(1.2); snap("03a-tool-selected-retry")
        }
        XCTAssertTrue(selectedDetails.waitForExistence(timeout: 6), "Selected tool card should expose a stable details button")
        XCTAssertTrue(selectedDetails.isHittable, "Selected tool details button should be hittable")
        selectedDetails.tap()
        wait(1.6); snap("03b-detail")
        let detailRoot = app.descendants(matching: .any)["RootSheet.ToolDetail"]
        XCTAssertTrue(detailRoot.waitForExistence(timeout: 5), "Tapping selected details should open the tool detail sheet")
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

        let resetToMap = app.buttons["RootShell.ShowUniverse"]
        if resetToMap.waitForExistence(timeout: 2), resetToMap.isHittable {
            resetToMap.tap()
            wait(0.8)
        }

        let showChat = app.buttons["RootShell.ShowChat"]
        XCTAssertTrue(showChat.waitForExistence(timeout: 3), "Map route should expose the Chat return control")
        if showChat.isHittable {
            showChat.tap()
        }
        wait(1.2)
        XCTAssertTrue(composer.waitForExistence(timeout: 3), "Ask-about-this should return to chat")
        let preseededValue = (composer.value as? String) ?? ""
        XCTAssertFalse(
            preseededValue.contains("PostHog") || preseededValue.contains("Founder OS"),
            "Overview Ask-about-this should not preseed a projected fallback tool context; got \(preseededValue)"
        )

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
                app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.30)).tap()
                wait(0.5)
                XCTAssertFalse(
                    files.exists,
                    "Tapping outside the attachment menu should dismiss it"
                )

                attach.tap(); wait(0.8)
                let reopenedFiles = app.buttons["chat-attachment-files"]
                XCTAssertTrue(reopenedFiles.waitForExistence(timeout: 2), "Attachment menu should reopen from the paperclip")
                if reopenedFiles.isHittable {
                    reopenedFiles.tap(); wait(0.8); snap("06-attached-pill")
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

    @MainActor
    private func firstHittableButton(
        _ app: XCUIApplication,
        identifierPrefix: String,
        timeout: TimeInterval
    ) -> XCUIElement? {
        let query = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", identifierPrefix))
        let deadline = Date().addingTimeInterval(timeout)

        repeat {
            for index in 0..<query.count {
                let candidate = query.element(boundBy: index)
                if candidate.exists, candidate.isHittable {
                    return candidate
                }
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        } while Date() < deadline

        return nil
    }

    @MainActor
    private func tapNode(_ element: XCUIElement, name: String) {
        if !element.isHittable {
            attachText("tree-\(name.replacingOccurrences(of: " ", with: "-"))-not-hittable", element.debugDescription)
        }
        XCTAssertTrue(element.isHittable, "\(name) should be hittable before tapping")
        element.tap()
    }
}
