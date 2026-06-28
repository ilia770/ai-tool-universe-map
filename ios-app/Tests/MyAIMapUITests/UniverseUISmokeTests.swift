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

        // Branch focus via a hittable 2D graph node accessibility label.
        let categoryNode = firstHittableButton(app, identifierPrefix: "ConstellationCategory.", timeout: 8)
        if categoryNode == nil {
            attachText("tree-no-hittable-category-node", app.debugDescription)
        }
        XCTAssertNotNil(categoryNode, "2D graph should expose at least one hittable category node")
        guard let categoryNode else { return }
        let categoryName = categoryName(from: categoryNode.label)
        let categoryID = identifierSuffix(from: categoryNode.identifier, prefix: "ConstellationCategory.")
        tapNode(categoryNode, name: "\(categoryName) category node")
        wait(1.6)
        snap("02-branch-\(categoryName)")
        attachText("tree-branch", app.debugDescription)

        let selectedBranch = app.staticTexts["PlanetInfoCard.SelectedBranch"].firstMatch
        XCTAssertTrue(selectedBranch.waitForExistence(timeout: 3), "Branch card should expose a stable selected branch label")
        XCTAssertTrue(
            selectedBranch.label.contains(categoryName),
            "Branch card should match the tapped \(categoryName) node; got \(selectedBranch.label)"
        )

        // Tool selection: tap a graph tool from the focused branch, then open its detail card.
        let branchToolIdentifiers = seedToolIDsByCategory[categoryID, default: []].map { "ConstellationStar.\($0)" }
        let toolNode = firstInteractableGraphButton(app, identifiers: branchToolIdentifiers, timeout: 8)
        if toolNode == nil {
            attachText("tree-no-hittable-focused-tool-node", app.debugDescription)
        }
        XCTAssertNotNil(toolNode, "\(categoryName) branch should expose at least one interactable focused tool node")
        guard let toolNode else { return }
        let toolName = toolName(from: toolNode.label)
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

    private var seedToolIDsByCategory: [String: [String]] {
        [
            "analytics": ["posthog"],
            "coding": ["codex", "claude-code", "cursor", "coderabbit", "cubic", "zed", "lovable", "bolt", "base44", "terax", "vscode"],
            "core": ["openswarm", "approval-gate", "wisprflow", "openclaw", "shannon", "planning-loop"],
            "design": ["figma", "dessn", "paper-design", "framer", "opendesign", "claude-design", "paperclip"],
            "distribution": ["buffer", "omnisocials", "distribution-loop"],
            "infrastructure": ["vercel", "docker", "warp", "react-tauri-xterm", "terminal", "supabase"],
            "knowledge": ["agent-skills", "mattpocock-skills", "designer-skills", "chorus-skills", "obsidian-skills"],
            "media": ["remotion", "hyperframes", "genmedia", "higgsfield", "affinity-adobe-blender", "runway", "heygen"],
            "research": ["supadata", "readwise", "deer-flow", "api-mega-list", "kimi-webbridge", "lazyweb"]
        ]
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
    private func firstInteractableGraphButton(
        _ app: XCUIApplication,
        identifiers: [String],
        timeout: TimeInterval
    ) -> XCUIElement? {
        let deadline = Date().addingTimeInterval(timeout)

        repeat {
            var firstVisibleFallback: XCUIElement?
            for identifier in identifiers {
                let candidate = app.buttons[identifier]
                if candidate.exists, candidate.isHittable {
                    return candidate
                }
                if firstVisibleFallback == nil, candidate.exists, isFullyVisibleGraphButton(candidate, in: app) {
                    firstVisibleFallback = candidate
                }
            }
            if let firstVisibleFallback {
                return firstVisibleFallback
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        } while Date() < deadline

        return nil
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

    private func categoryName(from label: String) -> String {
        nameComponent(from: label, prefix: "Category node, ")
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

    @MainActor
    private func isFullyVisibleGraphButton(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        let frame = element.frame
        let topChromeBottom: CGFloat = 196
        let bottomDockTop = app.frame.height - 214

        return frame.width > 1
            && frame.height > 1
            && frame.minX >= 0
            && frame.maxX <= app.frame.width
            && frame.minY >= topChromeBottom
            && frame.maxY <= bottomDockTop
    }
}
