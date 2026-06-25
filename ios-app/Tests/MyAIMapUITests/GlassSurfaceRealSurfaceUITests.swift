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
        addTool.tap()

        let auto = app.buttons["addTool.branchMode.0"]
        let manual = app.buttons["addTool.branchMode.1"]
        XCTAssertTrue(auto.waitForExistence(timeout: 5), "Add Tool sheet should expose Auto branch mode")
        XCTAssertTrue(manual.waitForExistence(timeout: 5), "Add Tool sheet should expose Manual branch mode")
        reveal(manual, in: app)

        assertLegalHitTarget(auto, name: "Auto branch mode")
        assertLegalHitTarget(manual, name: "Manual branch mode")
        XCTAssertTrue(waitForSelection(auto, selected: true), "Auto should be selected by default")
        XCTAssertTrue(waitForSelection(manual, selected: false), "Manual should not be selected by default")

        manual.tap()
        XCTAssertTrue(waitForSelection(manual, selected: true), "Tapping Manual should move selection")
        XCTAssertTrue(waitForSelection(auto, selected: false), "Auto should lose selection after Manual is tapped")
        snap("glass-surface-addtool-branch-mode")
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
        account.tap()

        let settings = app.buttons["account.section.0"]
        let history = app.buttons["account.section.1"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5), "Account sheet should expose Settings section")
        XCTAssertTrue(history.waitForExistence(timeout: 5), "Account sheet should expose History section")

        assertLegalHitTarget(settings, name: "Settings section")
        assertLegalHitTarget(history, name: "History section")
        XCTAssertTrue(waitForSelection(settings, selected: true), "Settings should be selected by default")
        XCTAssertTrue(waitForSelection(history, selected: false), "History should not be selected by default")

        history.tap()
        XCTAssertTrue(waitForSelection(history, selected: true), "Tapping History should move selection")
        XCTAssertTrue(waitForSelection(settings, selected: false), "Settings should lose selection after History is tapped")
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
        for element in [askAI, addTool, exploreMap, skip] {
            XCTAssertTrue(element.waitForExistence(timeout: 3), "\(element) should exist on onboarding")
            assertLegalHitTarget(element, name: element.identifier)
        }

        snap("glass-surface-onboarding")
        skip.tap()
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
    askAI.tap()
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
        showChat.tap()
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
    XCTAssertGreaterThanOrEqual(element.frame.width, 44, "\(name) width should be at least 44pt", file: file, line: line)
    XCTAssertGreaterThanOrEqual(element.frame.height, 44, "\(name) height should be at least 44pt", file: file, line: line)
}

@MainActor
private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
    guard !element.isHittable else { return }
    let scrollView = app.scrollViews.firstMatch
    for _ in 0..<4 where !element.isHittable {
        if scrollView.exists {
            scrollView.swipeUp()
        } else {
            app.swipeUp()
        }
        RunLoop.current.run(until: Date().addingTimeInterval(0.25))
    }
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
private func snap(_ name: String, file: StaticString = #filePath, line: UInt = #line) {
    let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    XCTContext.runActivity(named: "Screenshot: \(name)") { activity in
        activity.add(attachment)
    }
}
