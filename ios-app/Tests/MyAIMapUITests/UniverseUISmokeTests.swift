import XCTest

/// Visual smoke harness. Launches with `-uitestStatic` so the app forces Reduce
/// Motion (no perpetual RealityKit spin/pulse) and can reach quiescence — only
/// then can XCUITest take accessibility snapshots / screenshots reliably. Drives
/// key states by element where possible and saves kept screenshots for human
/// review of QA_REGRESSION_CHECKLIST. Manual-only (not in the default test action).
final class UniverseUISmokeTests: XCTestCase {

    override func setUp() {
        continueAfterFailure = true
        executionTimeAllowance = 300
    }

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
        wait(0.8)
        let showChatAfterMapTap = app.buttons["RootShell.ShowChat"]
        XCTAssertTrue(showChatAfterMapTap.waitForExistence(timeout: 5), "Chat -> Map route should expose the Ask AI return control before reset")
        XCTAssertTrue(waitForHittable(showChatAfterMapTap, timeout: 3), "Ask AI return control should be hittable after Chat -> Map")
        relaunchSampleMap(app)
        snap("02-overview")
        attachText("tree-overview", app.debugDescription)

        // Use the known Coding → Codex → Claude Code relation so this smoke can
        // exercise the compact detail replacement route deterministically.
        let categoryNode = app.buttons["ConstellationCategory.coding"]
        XCTAssertTrue(categoryNode.waitForExistence(timeout: 8), "2D graph should expose the Coding category node")
        XCTAssertTrue(waitForHittable(categoryNode, timeout: 5), "Coding category should be hittable")
        tapNode(categoryNode, name: "Coding category node")
        wait(1.6)
        snap("02-branch-Coding")
        attachText("tree-branch", app.debugDescription)

        // The Codex star exists only in focused Coding, so its presence and
        // hit target are the branch-focus assertion before tool selection.
        let toolNode = app.buttons["ConstellationStar.codex"]
        XCTAssertTrue(toolNode.waitForExistence(timeout: 8), "Coding branch should expose the Codex tool node")
        XCTAssertTrue(waitForHittable(toolNode, timeout: 5), "Focused Codex tool node should be hittable")
        let toolName = toolName(from: toolNode.label)
        let toolID = identifierSuffix(from: toolNode.identifier, prefix: "ConstellationStar.")
        tapGraphNode(toolNode, name: "tool node", app: app)
        wait(1.8); snap("03a-tool-selected")
        let selectedDetails = app.buttons["PlanetInfoCard.SelectedDetails"].firstMatch
        var didExposeSelectedDetails = selectedDetails.waitForExistence(timeout: 6)
        if !didExposeSelectedDetails {
            attachText("tree-tool-selected-missing-details", app.debugDescription)
            tapGraphNode(toolNode, name: "tool node retry", app: app)
            wait(1.2); snap("03a-tool-selected-retry")
            didExposeSelectedDetails = selectedDetails.waitForExistence(timeout: 4)
        }
        XCTAssertTrue(didExposeSelectedDetails, "Selected tool card should expose a stable details button")
        guard didExposeSelectedDetails else { return }
        XCTAssertTrue(
            selectedDetails.label.contains(toolName),
            "Coordinate tap should select \(toolName), got selected card label: \(selectedDetails.label)"
        )
        XCTAssertTrue(selectedDetails.isHittable, "Selected tool details button should be hittable")
        let didOpenDetail = openSelectedToolDetail(app, selectedDetails: selectedDetails, toolName: toolName)
        snap("03b-detail")
        if !didOpenDetail {
            attachText("tree-detail-open-missing", app.debugDescription)
        }
        XCTAssertTrue(didOpenDetail, "Tapping selected details should open the tool detail sheet")
        guard didOpenDetail else { return }

        let detailRoot = app.descendants(matching: .any)["RootSheet.ToolDetail"].firstMatch
        let detailClose = app.buttons["UniverseDetail.Close"]
        XCTAssertTrue(detailClose.waitForExistence(timeout: 3), "Detail sheet should expose a visible close action")
        XCTAssertTrue(waitForHittable(detailClose, timeout: 3), "Detail close should be hittable before tap")
        detailClose.tap()
        XCTAssertTrue(waitForNonExistence(detailRoot, timeout: 5), "Visible close should fully dismiss detail")

        let returnNode = app.buttons["ConstellationStar.\(toolID)"]
        XCTAssertTrue(returnNode.waitForExistence(timeout: 5), "Dismissal should restore the original map node")
        XCTAssertTrue(waitForHittable(returnNode, timeout: 5), "Restored map node should remain hittable")

        // Reopen immediately, then verify that a cancelled partial drag keeps
        // the sheet visible before continuing to related-tool replacement.
        XCTAssertTrue(openSelectedToolDetail(app, selectedDetails: selectedDetails, toolName: toolName))
        let partialDragStart = detailRoot.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.04))
        let partialDragEnd = detailRoot.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12))
        partialDragStart.press(forDuration: 0.1, thenDragTo: partialDragEnd)
        wait(0.7)
        XCTAssertTrue(
            waitForToolDetailVisible(app, toolName: toolName, timeout: 3),
            "A cancelled partial sheet drag must preserve the detail route"
        )

        // Select a known related tool in the same sheet. The route replacement
        // must update content without a second presentation flag or new sheet.
        for _ in 0..<3 where !app.buttons["More"].exists {
            detailRoot.swipeUp()
            wait(0.3)
        }
        let more = app.buttons["More"].firstMatch
        XCTAssertTrue(more.waitForExistence(timeout: 3), "Detail should expose the related-tools disclosure")
        tapElement(more, name: "detail more", app: app)
        wait(0.5)

        let relatedTool = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Claude Code")).firstMatch
        XCTAssertTrue(relatedTool.waitForExistence(timeout: 3), "Codex detail should expose Claude Code as a related tool")
        tapElement(relatedTool, name: "related Claude Code", app: app)
        XCTAssertTrue(
            waitForToolDetailVisible(app, toolName: "Claude Code", timeout: 5),
            "Related-tool selection should replace the visible detail tool"
        )

        let relatedClose = app.buttons["UniverseDetail.Close"]
        tapElement(relatedClose, name: "related detail close", app: app)
        XCTAssertTrue(waitForNonExistence(detailRoot, timeout: 5), "Related detail should dismiss cleanly")
        let relatedReturnNode = app.buttons["ConstellationStar.claude-code"]
        XCTAssertTrue(relatedReturnNode.waitForExistence(timeout: 5), "Dismissal should restore the related tool node")
        XCTAssertTrue(waitForHittable(relatedReturnNode, timeout: 5), "Related return node should be hittable")
        relaunchSampleMap(app)

        // Rail — press-drag the right edge while the map is active (best-effort).
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.94, dy: 0.52))
            .press(forDuration: 0.6,
                   thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.94, dy: 0.42)))
        wait(0.6)
        ensureAppForeground(app)
        snap("08-after-rail-drag")

        let resetToMap = app.buttons["RootShell.ShowUniverse"]
        if resetToMap.waitForExistence(timeout: 2), waitForHittable(resetToMap, timeout: 2) {
            resetToMap.tap()
            wait(0.8)
        }

        let showChat = app.buttons["RootShell.ShowChat"]
        XCTAssertTrue(showChat.waitForExistence(timeout: 3), "Map route should expose the Chat return control")
        XCTAssertTrue(waitForHittable(showChat, timeout: 5), "Chat return control should become hittable")
        showChat.tap()
        wait(1.2)
        XCTAssertTrue(composer.waitForExistence(timeout: 3), "Ask-about-this should return to chat")
        let preseededValue = (composer.value as? String) ?? ""
        XCTAssertFalse(
            (!toolName.isEmpty && preseededValue.contains(toolName)) || preseededValue.contains("Founder OS"),
            "Overview Ask-about-this should not preseed a projected fallback tool context; got \(preseededValue)"
        )

        // Account sheet from the chat shell, before keyboard focus can affect idle waits.
        let account = app.buttons["ChatScreen.Account"]
        if account.waitForExistence(timeout: 3), account.isHittable {
            account.tap(); wait(1.4); snap("07-account")
            let closeAccount = app.buttons.matching(
                NSPredicate(format: "identifier == %@ AND label == %@", "xmark", "Close")
            ).firstMatch
            XCTAssertTrue(closeAccount.waitForExistence(timeout: 3), "Account sheet should expose a close button")
            if closeAccount.exists {
                tapElement(closeAccount, name: "account close", app: app)
                wait(0.8)
            }
            XCTAssertTrue(waitForNonExistence(app.navigationBars["Account"], timeout: 3), "Account sheet should dismiss before chat input checks")
        }

        // Input focus (not-black confirmation).
        let field = app.textFields["chat-composer-field"]
        if field.waitForExistence(timeout: 3) {
            tapElement(field, name: "chat composer field", app: app)
            wait(1.4); snap("04-input-focus")
            // Attachment menu while focused.
            let attach = app.buttons["chat-attach-button"]
            if attach.waitForExistence(timeout: 2) {
                let files = openAttachmentMenu(app, attach: attach, name: "attachment button")
                snap("05-attach-menu")
                XCTAssertNotNil(files, "Attachment menu should expose Files")
                if let files {
                    app.coordinate(withNormalizedOffset: CGVector(dx: 0.90, dy: 0.44)).tap()
                    wait(0.5)
                    XCTAssertTrue(
                        waitForNonExistence(files, timeout: 3),
                        "Tapping outside the attachment menu should dismiss it"
                    )

                    let reopenedFiles = openAttachmentMenu(app, attach: attach, name: "attachment button reopen")
                    XCTAssertNotNil(reopenedFiles, "Attachment menu should reopen from the paperclip")
                    if let reopenedFiles, reopenedFiles.isHittable {
                        reopenedFiles.tap(); wait(0.8); snap("06-attached-pill")
                    }
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
    private func ensureAppForeground(_ app: XCUIApplication) {
        guard app.state != .runningForeground else { return }

        if app.state == .notRunning || app.state == .unknown {
            app.launch()
        } else {
            app.activate()
        }
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 8), "Smoke app should remain foreground")
        wait(0.8)
    }

    @MainActor
    private func relaunchSampleMap(_ app: XCUIApplication) {
        app.terminate()
        wait(0.6)
        app.launchArguments = ["-uitestStatic", "-uitestSampleUniverse"]
        app.launch()
        wait(2.5)
        XCTAssertTrue(
            app.buttons["RootShell.ShowChat"].waitForExistence(timeout: 8),
            "Relaunched sample map should expose the Ask AI route"
        )
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
    private func waitForHittable(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if element.exists, element.isHittable {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        } while Date() < deadline

        return element.exists && element.isHittable
    }

    @MainActor
    private func waitForNonExistence(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if !element.exists {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        } while Date() < deadline

        return !element.exists
    }

    @MainActor
    private func openAttachmentMenu(
        _ app: XCUIApplication,
        attach: XCUIElement,
        name: String
    ) -> XCUIElement? {
        let files = app.buttons["chat-attachment-files"].firstMatch
        let photo = app.buttons["chat-attachment-photo"].firstMatch
        let slug = name.replacingOccurrences(of: " ", with: "-")

        for attempt in 1...2 {
            if attempt == 1 {
                tapElement(attach, name: name, app: app)
            } else {
                tapElementCenter(attach, name: "\(name) retry", app: app)
            }

            let deadline = Date().addingTimeInterval(4)
            repeat {
                if files.exists {
                    return files
                }
                RunLoop.current.run(until: Date().addingTimeInterval(0.2))
            } while Date() < deadline

            attachText("tree-\(slug)-menu-missing-\(attempt)", app.debugDescription)
            if photo.exists {
                return nil
            }
        }

        return files.exists ? files : nil
    }

    @MainActor
    private func waitForToolDetailVisible(_ app: XCUIApplication, toolName: String, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        let detailRoot = app.descendants(matching: .any)["RootSheet.ToolDetail"]
        let detailTitle = app.staticTexts["ToolDetailSection.Title"].firstMatch

        repeat {
            if detailRoot.exists,
               detailTitle.exists,
               detailTitle.label.contains(toolName) {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        } while Date() < deadline

        return detailRoot.exists
            && detailTitle.exists
            && detailTitle.label.contains(toolName)
    }

    private func toolName(from label: String) -> String {
        nameComponent(from: label, prefix: "Tool node, ")
    }

    private func identifierSuffix(from identifier: String, prefix: String) -> String {
        identifier.hasPrefix(prefix) ? String(identifier.dropFirst(prefix.count)) : identifier
    }

    private func nameComponent(from label: String, prefix: String) -> String {
        let withoutPrefix = label.hasPrefix(prefix) ? String(label.dropFirst(prefix.count)) : label
        return withoutPrefix.split(separator: ",", maxSplits: 1).first.map(String.init) ?? withoutPrefix
    }

    @MainActor
    private func tapNode(_ element: XCUIElement, name: String) {
        if !element.isHittable {
            attachText("tree-\(name.replacingOccurrences(of: " ", with: "-"))-not-hittable", element.debugDescription)
        }
        XCTAssertTrue(element.isHittable, "\(name) should be hittable before tapping")
        element.tap()
    }

    @MainActor
    private func tapGraphNode(_ element: XCUIElement, name: String, app: XCUIApplication) {
        tapElement(element, name: name, app: app)
    }

    @MainActor
    private func tapElement(_ element: XCUIElement, name: String, app: XCUIApplication) {
        if element.isHittable {
            element.tap()
            return
        }

        let frame = element.frame
        attachText("tree-\(name.replacingOccurrences(of: " ", with: "-"))-coordinate-tap", element.debugDescription)
        app.coordinate(
            withNormalizedOffset: CGVector(
                dx: frame.midX / app.frame.width,
                dy: frame.midY / app.frame.height
            )
        ).tap()
    }

    @MainActor
    private func openSelectedToolDetail(
        _ app: XCUIApplication,
        selectedDetails: XCUIElement,
        toolName: String
    ) -> Bool {
        tapElement(selectedDetails, name: "selected details", app: app)
        if waitForToolDetailVisible(app, toolName: toolName, timeout: 8) {
            return true
        }

        attachText("tree-detail-open-missing-after-element-tap", app.debugDescription)
        guard !app.descendants(matching: .any)["RootSheet.ToolDetail"].exists else {
            return false
        }

        tapElementCenter(selectedDetails, name: "selected details retry", app: app)
        return waitForToolDetailVisible(app, toolName: toolName, timeout: 6)
    }

    @MainActor
    private func tapElementCenter(_ element: XCUIElement, name: String, app: XCUIApplication) {
        let frame = element.frame
        attachText("tree-\(name.replacingOccurrences(of: " ", with: "-"))-center-tap", element.debugDescription)
        app.coordinate(
            withNormalizedOffset: CGVector(
                dx: frame.midX / app.frame.width,
                dy: frame.midY / app.frame.height
            )
        ).tap()
    }

}
