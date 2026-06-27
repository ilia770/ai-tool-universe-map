import XCTest

/// Manual visual-capture harness for the polish sprint. Drives the states the
/// main smoke harness does not cover (3D spatial scene, Add Tool sheet, account
/// History tab) and saves screenshots for human review. Not part of the default
/// test action — run on demand:
///   xcodebuild test -only-testing:MyAIMapUITests/PolishCaptureTests/testCaptureExtraStates
final class PolishCaptureTests: XCTestCase {

    override func setUp() {
        continueAfterFailure = true
        executionTimeAllowance = 300
    }

    @MainActor
    func testCaptureExtraStates() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitestStatic", "-uitestSampleUniverse"]
        app.launch()
        wait(2.5)

        // 3D Spatial scene.
        let toggle3D = app.buttons["universe.renderMode.1"]
        if toggle3D.waitForExistence(timeout: 5) {
            tap(toggle3D)
            wait(2.5)
            snap("10-3d-spatial")
        }
        // Back to 2D for the remaining captures (the on-map toggle is hidden in
        // 3D now; the experimental notice owns the exit).
        let exit2D = app.buttons["spatial-exit-to-2d"]
        if exit2D.waitForExistence(timeout: 3) {
            tap(exit2D)
            wait(1.2)
        }

        // Add Tool sheet (idle, then name focused).
        let addTool = app.buttons["chat-add-tool-button"]
        if addTool.waitForExistence(timeout: 4), addTool.isHittable {
            tap(addTool)
            wait(1.2)
            snap("11-addtool-idle")
            let nameField = app.textFields.firstMatch
            if nameField.waitForExistence(timeout: 3) {
                tap(nameField)
                nameField.typeText("Firecrawl")
                wait(1.0)
                snap("12-addtool-name")
            }
            // Dismiss the sheet.
            let cancel = app.buttons.matching(
                NSPredicate(format: "label CONTAINS[c] 'Cancel' OR identifier CONTAINS[c] 'cancel'")
            ).firstMatch
            if cancel.waitForExistence(timeout: 2), cancel.isHittable { tap(cancel) }
            wait(0.8)
        }

        // Account → History tab.
        let account = app.buttons["Account"].firstMatch
        if account.waitForExistence(timeout: 3), account.isHittable {
            tap(account)
            wait(1.2)
            let history = app.buttons["account.section.1"]
            if history.waitForExistence(timeout: 3), history.isHittable {
                tap(history)
                wait(0.8)
                snap("13-account-history")
            }
        }
    }

    @MainActor
    func testCaptureEmptyState() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitestStatic", "-uitestOnboarding"]
        app.launch()
        wait(2.0)
        // First-run onboarding over the empty map.
        snap("20-onboarding")
        // Skip → the empty universe map (first-run, no tools yet).
        let skip = app.buttons["Onboarding.Skip"]
        if skip.waitForExistence(timeout: 4), skip.isHittable {
            tap(skip)
            wait(1.5)
            snap("21-empty-map")
        }
    }

    // MARK: - Helpers

    @MainActor private func tap(_ element: XCUIElement) {
        if element.isHittable {
            element.tap()
        } else {
            element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
    }

    @MainActor private func wait(_ seconds: TimeInterval) {
        let exp = expectation(description: "wait")
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { exp.fulfill() }
        wait(for: [exp], timeout: seconds + 2)
    }

    @MainActor private func snap(_ name: String) {
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
