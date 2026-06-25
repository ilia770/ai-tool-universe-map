import XCTest

final class GlassSurfaceAddToolBranchModeUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testBranchModeClusterMorphsSelectionAndHasLegalHitTargets() {
        let app = launchOnboardingApp()
        openEmptyChatFromOnboarding(app)

        let addTool = app.buttons["chat-add-tool-button"]
        XCTAssertTrue(addTool.waitForExistence(timeout: 5), "Chat surface should expose Add Tool")
        tapWhenHittable(addTool, name: "Chat Add Tool button")

        let auto = app.buttons["addTool.branchMode.0"]
        let manual = app.buttons["addTool.branchMode.1"]
        XCTAssertTrue(auto.waitForExistence(timeout: 5), "Add Tool sheet should expose Auto branch mode")
        XCTAssertTrue(manual.waitForExistence(timeout: 5), "Add Tool sheet should expose Manual branch mode")
        XCTAssertTrue(reveal(manual, in: app), "Manual branch mode should be hittable after reveal")

        assertLegalHitTarget(auto, name: "Auto branch mode")
        assertLegalHitTarget(manual, name: "Manual branch mode")
        XCTAssertTrue(waitForSelection(auto, selected: true), "Auto should be selected by default")
        XCTAssertTrue(waitForSelection(manual, selected: false), "Manual should not be selected by default")

        tapWhenHittable(manual, name: "Manual branch mode")
        XCTAssertTrue(waitForSelection(manual, selected: true), "Tapping Manual should move selection")
        XCTAssertTrue(waitForSelection(auto, selected: false), "Auto should lose selection after Manual is tapped")
        settle()
        snap("glass-surface-addtool-branch-mode")
    }

    @MainActor
    func testBranchModeRemainsReachableWithNameKeyboardOpen() {
        let app = launchOnboardingApp()
        openEmptyChatFromOnboarding(app)

        let addTool = app.buttons["chat-add-tool-button"]
        XCTAssertTrue(addTool.waitForExistence(timeout: 5), "Chat surface should expose Add Tool")
        tapWhenHittable(addTool, name: "Chat Add Tool button")

        let nameField = app.textFields["addTool.nameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "Add Tool sheet should expose the Name field")
        tapWhenHittable(nameField, name: "Add Tool Name field")
        nameField.typeText("PostHog")
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "Name focus should show the keyboard")

        let auto = app.buttons["addTool.branchMode.0"]
        let manual = app.buttons["addTool.branchMode.1"]
        XCTAssertTrue(reveal(manual, in: app), "Branch mode should remain reachable with the keyboard open")
        assertLegalHitTarget(auto, name: "Auto branch mode with keyboard")
        assertLegalHitTarget(manual, name: "Manual branch mode with keyboard")
        settle()
        snap("glass-surface-addtool-keyboard")
    }
}

final class GlassSurfaceAccountSectionUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testAccountSectionClusterMorphsSelectionAndHasLegalHitTargets() {
        let app = launchSampleApp()
        openChat(app)

        let account = app.buttons["ChatScreen.Account"]
        XCTAssertTrue(account.waitForExistence(timeout: 5), "Chat surface should expose Account")
        tapWhenHittable(account, name: "Account button")

        let settings = app.buttons["account.section.0"]
        let history = app.buttons["account.section.1"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5), "Account sheet should expose Settings section")
        XCTAssertTrue(history.waitForExistence(timeout: 5), "Account sheet should expose History section")

        assertLegalHitTarget(settings, name: "Settings section")
        assertLegalHitTarget(history, name: "History section")
        XCTAssertTrue(waitForSelection(settings, selected: true), "Settings should be selected by default")
        XCTAssertTrue(waitForSelection(history, selected: false), "History should not be selected by default")

        tapWhenHittable(history, name: "History section")
        XCTAssertTrue(waitForSelection(history, selected: true), "Tapping History should move selection")
        XCTAssertTrue(waitForSelection(settings, selected: false), "Settings should lose selection after History is tapped")
        settle()
        snap("glass-surface-settings-section")
    }
}

final class GlassSurfaceOnboardingUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testOnboardingControlsHaveLegalHitTargetsAndSkipDismisses() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitestStatic", "-uitestOnboarding"]
        app.launch()

        let askAI = app.buttons["Onboarding.AskAI"]
        let addTool = app.buttons["Onboarding.AddTool"]
        let exploreMap = app.buttons["Onboarding.ExploreMap"]
        let skip = app.buttons["Onboarding.Skip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 8), "-uitestOnboarding should force the first-run overlay")
        XCTAssertFalse(app.buttons["RootShell.ShowChat"].exists, "Onboarding should suppress the root Ask AI/Map switch")
        XCTAssertFalse(app.buttons["RootShell.ShowUniverse"].exists, "Onboarding should suppress the root Ask AI/Map switch")
        for element in [askAI, addTool, exploreMap, skip] {
            XCTAssertTrue(element.waitForExistence(timeout: 3), "\(element) should exist on onboarding")
            assertLegalHitTarget(element, name: element.identifier)
        }

        settle()
        snap("glass-surface-onboarding")
        tapWhenHittable(skip, name: "Onboarding Skip")
        XCTAssertTrue(waitForNonExistence(app.buttons["Onboarding.Skip"]), "Skip should dismiss onboarding")
    }
}

@MainActor
private func launchSampleApp() -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = ["-uitestStatic", "-uitestSampleUniverse"]
    app.launch()
    return app
}

@MainActor
private func launchOnboardingApp() -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = ["-uitestStatic", "-uitestOnboarding"]
    app.launch()
    return app
}

@MainActor
private func openEmptyChatFromOnboarding(_ app: XCUIApplication) {
    let askAI = app.buttons["Onboarding.AskAI"]
    XCTAssertTrue(askAI.waitForExistence(timeout: 20), "First-run overlay should expose Ask AI")
    tapWhenHittable(askAI, name: "Onboarding Ask AI")
    XCTAssertTrue(
        app.textFields["chat-composer-field"].waitForExistence(timeout: 8),
        "Ask AI onboarding action should open chat with an empty composer"
    )
}

@MainActor
private func openChat(_ app: XCUIApplication) {
    let showChat = app.buttons["RootShell.ShowChat"]
    XCTAssertTrue(showChat.waitForExistence(timeout: 8), "Map surface should expose Ask AI")
    if !showChat.isSelected {
        tapWhenHittable(showChat, name: "Show Chat")
    }
    XCTAssertTrue(
        app.textFields["chat-composer-field"].waitForExistence(timeout: 8),
        "Ask AI surface should expose the composer"
    )
}

@MainActor
private func assertLegalHitTarget(
    _ element: XCUIElement,
    name: String,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    XCTAssertTrue(element.exists, "\(name) should exist", file: file, line: line)
    XCTAssertTrue(element.isHittable, "\(name) should be hittable", file: file, line: line)
    XCTAssertGreaterThanOrEqual(element.frame.width, 44, "\(name) width should be at least 44pt", file: file, line: line)
    XCTAssertGreaterThanOrEqual(element.frame.height, 44, "\(name) height should be at least 44pt", file: file, line: line)
    XCTAssertFalse(element.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "\(name) should expose an accessibility label", file: file, line: line)
}

@MainActor
private func tapWhenHittable(
    _ element: XCUIElement,
    name: String,
    timeout: TimeInterval = 5,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    XCTAssertTrue(waitForHittable(element, timeout: timeout), "\(name) should be hittable before tap", file: file, line: line)
    element.tap()
}

@MainActor
private func waitForHittable(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    repeat {
        if element.exists, element.isHittable {
            return true
        }
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
    } while Date() < deadline
    return element.exists && element.isHittable
}

@MainActor
private func reveal(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
    guard !element.isHittable else { return true }
    let scrollView = app.scrollViews.firstMatch
    for _ in 0..<4 where !element.isHittable {
        if scrollView.exists {
            scrollView.swipeUp()
        } else {
            app.swipeUp()
        }
        RunLoop.current.run(until: Date().addingTimeInterval(0.25))
    }
    return element.exists && element.isHittable
}

@MainActor
private func waitForSelection(_ element: XCUIElement, selected: Bool, timeout: TimeInterval = 3) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    repeat {
        if element.exists, element.isSelected == selected {
            return true
        }
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
    } while Date() < deadline
    return element.exists && element.isSelected == selected
}

@MainActor
private func waitForNonExistence(_ element: XCUIElement, timeout: TimeInterval = 4) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    repeat {
        if !element.exists {
            return true
        }
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
    } while Date() < deadline
    return !element.exists
}

@MainActor
private func settle(_ duration: TimeInterval = 0.25) {
    RunLoop.current.run(until: Date().addingTimeInterval(duration))
}

@MainActor
private func snap(_ name: String, file: StaticString = #filePath, line: UInt = #line) {
    let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    XCTContext.runActivity(named: "Screenshot: \(name)") { activity in
        activity.add(attachment)
    }
}
