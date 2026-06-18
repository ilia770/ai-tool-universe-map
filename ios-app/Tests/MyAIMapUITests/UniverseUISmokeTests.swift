import XCTest

/// Visual smoke: drives the app to key UI states by ACCESSIBILITY ELEMENT (not
/// raw coordinates — those hit the 3D scene's empty-tap and just reset), saving
/// a kept screenshot of each so a human can review the QA_REGRESSION_CHECKLIST
/// (state consistency, input-focus-not-black, attachment menu, branch focus,
/// detail, account). Also attaches the element tree for discovery.
final class UniverseUISmokeTests: XCTestCase {

    @MainActor
    func testCaptureKeyStates() {
        let app = XCUIApplication()
        app.launch()
        wait(3.0)
        snap("01-overview")
        attachText("tree-overview", app.debugDescription)

        // 1) Input focus — regression test for "focus blacks out universe".
        let field = app.textFields.firstMatch
        if field.waitForExistence(timeout: 5) {
            field.tap()
            wait(1.6)
            snap("02-input-focus")
            attachText("tree-focused", app.debugDescription)
        } else {
            attachText("02-no-textfield", "textFields.firstMatch not found")
        }

        // 2) Attachment menu (button label set in code: "Attach photo or file").
        let attach = app.buttons["Attach photo or file"]
        if attach.waitForExistence(timeout: 3) {
            attach.tap()
            wait(1.2)
            snap("03-attach-menu")
            // dismiss the menu if it opened
            if app.buttons["Files"].waitForExistence(timeout: 2) {
                app.buttons["Files"].tap() // selects an attachment -> file pill
                wait(1.0)
                snap("03b-attached-pill")
            }
        }

        // 3) Category branch focus — try known chip labels.
        for label in ["Design", "Coding", "Research", "Analytics", "Media", "Distribution"] {
            let chip = app.buttons[label]
            if chip.exists {
                chip.tap()
                wait(2.0)
                snap("04-branch-\(label)")
                break
            }
        }
        attachText("tree-branch", app.debugDescription)

        // 4) Detail — re-tap the selected tool / open card. Try a Details button.
        for label in ["Details", "Open details", "View details"] {
            let b = app.buttons[label]
            if b.exists { b.tap(); wait(1.6); snap("05-detail"); break }
        }

        // 5) Account sheet (button label "Account").
        let account = app.buttons["Account"]
        if account.waitForExistence(timeout: 3) {
            account.tap()
            wait(1.8)
            snap("06-account")
        }
    }

    private func wait(_ seconds: TimeInterval) {
        let exp = expectation(description: "wait")
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { exp.fulfill() }
        wait(for: [exp], timeout: seconds + 2)
    }

    private func snap(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func attachText(_ name: String, _ text: String) {
        let attachment = XCTAttachment(string: text)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
