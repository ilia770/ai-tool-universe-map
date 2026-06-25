import XCTest

final class GlassMorphClusterUITests: XCTestCase {
    func testTappingOptionMorphsSelectionAndHasLegalHitTarget() {
        let app = XCUIApplication()
        app.launchArguments += ["-uitestGlassDemo"]
        app.launch()

        let readout = app.staticTexts["GlassDemo.selectedIndex"]
        XCTAssertTrue(readout.waitForExistence(timeout: 10))
        XCTAssertEqual(readout.value as? String, "0")

        let passport = app.buttons["GlassDemo.cluster.2"]
        XCTAssertTrue(passport.waitForExistence(timeout: 5))
        // HIG hit target: the tappable frame is at least 44x44pt.
        XCTAssertGreaterThanOrEqual(passport.frame.height, 44)
        XCTAssertGreaterThanOrEqual(passport.frame.width, 44)

        passport.tap()
        XCTAssertEqual(readout.value as? String, "2")
    }
}
