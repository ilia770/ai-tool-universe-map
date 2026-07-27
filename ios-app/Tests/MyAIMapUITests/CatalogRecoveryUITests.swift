import XCTest

/// Covers the app-level recovery gate using an isolated Debug-only corrupt
/// catalog fixture. The test never reads or modifies a person's real catalog.
final class CatalogRecoveryUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testAccountSettingsExposeNativeCatalogTransferEntryPoints() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitestStatic", "-uitestSampleUniverse"]
        app.launch()

        let showChat = app.buttons["RootShell.ShowChat"]
        XCTAssertTrue(showChat.waitForExistence(timeout: 8))
        showChat.tap()

        let account = app.buttons["ChatScreen.Account"]
        XCTAssertTrue(account.waitForExistence(timeout: 5))
        account.tap()

        XCTAssertTrue(app.navigationBars["Account"].waitForExistence(timeout: 5))
        XCTAssertTrue(
            app.buttons["Export universe"].waitForExistence(timeout: 3),
            "Settings must expose the native validated-catalog export entry point"
        )
        XCTAssertTrue(
            app.buttons["Import universe"].waitForExistence(timeout: 3),
            "Settings must expose the native security-scoped catalog import entry point"
        )
        XCTAssertTrue(
            app.staticTexts["settings.dataPrivacy"].waitForExistence(timeout: 3),
            "Settings must disclose local-data retention and deletion behavior"
        )
    }

    @MainActor
    func testRecoveryRequiresConfirmationBeforeReplacingCatalog() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitestStatic", "-uitestCorruptCatalog"]
        app.launch()

        let recoveryTitle = app.staticTexts["Your universe needs recovery"]
        XCTAssertTrue(
            recoveryTitle.waitForExistence(timeout: 8),
            "Unreadable local catalog must be stopped by the app-level recovery gate"
        )

        let exportCopy = app.buttons["catalogRecovery.exportCopy"]
        XCTAssertTrue(
            exportCopy.waitForExistence(timeout: 3),
            "Recovery should offer the byte-for-byte corrupt catalog copy before replacement"
        )

        let startEmpty = app.buttons["catalogRecovery.startEmpty"]
        XCTAssertTrue(startEmpty.waitForExistence(timeout: 3))
        startEmpty.tap()

        let destructiveConfirmation = app.buttons["Start empty universe"]
        XCTAssertTrue(
            destructiveConfirmation.waitForExistence(timeout: 3),
            "The destructive replacement must require an explicit second confirmation"
        )
        XCTAssertTrue(
            startEmpty.exists && recoveryTitle.exists,
            "Opening the confirmation must not replace the catalog before its destructive action is tapped"
        )

        destructiveConfirmation.tap()

        XCTAssertTrue(
            app.buttons["RootShell.ShowChat"].waitForExistence(timeout: 8),
            "Only confirmed replacement may return the person to the normal app"
        )
        XCTAssertFalse(recoveryTitle.exists, "Recovery gate should close after the confirmed replacement succeeds")
    }
}
