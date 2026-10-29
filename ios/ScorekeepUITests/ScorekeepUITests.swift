import XCTest

/// End-to-end smoke test of the core loop on a real simulator: add players, score, undo, end the game.
final class ScorekeepUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testScoreAGame() {
        let app = XCUIApplication()
        // Fresh scratch store, never the device's saved game.
        app.launchArguments = ["-demo", "empty"]
        app.launch()

        app.buttons["Add your first player"].tap()
        addName("MAYA", in: app)

        app.buttons["Add player"].firstMatch.tap()
        // The tips cover the list (and hide it from VoiceOver), so check for LEO after them.
        addName("LEO", in: app, waitForRow: false)

        // First run: the tips appear once there are two players, and "Got it" closes them.
        let gotIt = app.buttons["Got it"]
        XCTAssertTrue(gotIt.waitForExistence(timeout: 5))
        gotIt.tap()
        XCTAssertTrue(gotIt.waitForNonExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["LEO"].waitForExistence(timeout: 5))

        let addToMaya = app.buttons["Add 1 to MAYA"]
        XCTAssertTrue(addToMaya.waitForExistence(timeout: 5))
        addToMaya.tap()
        addToMaya.tap()
        addToMaya.tap()
        XCTAssertTrue(app.staticTexts["MAYA score 3"].waitForExistence(timeout: 2))

        // Undo reverts the latest taps. (Taps within 2 s are one step; simulator taps
        // can be slower than that, so how far it goes back is unit-tested instead.)
        app.buttons["Undo"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["MAYA score 3"].waitForNonExistence(timeout: 2))

        let addToLeo = app.buttons["Add 1 to LEO"]
        for _ in 0..<4 { addToLeo.tap() }
        XCTAssertTrue(app.staticTexts["LEO score 4"].waitForExistence(timeout: 2))

        app.buttons["End game and show winner"].tap()
        XCTAssertTrue(app.staticTexts["Wins!"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["LEO"].exists)
        app.buttons["Back"].tap()
        XCTAssertTrue(app.staticTexts["LEO score 4"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func addName(_ name: String, in app: XCUIApplication, waitForRow: Bool = true) {
        let field = app.textFields["playerNameField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        // Return submits the sheet (the keyboard's key is also labeled "Done").
        field.typeText(name + "\n")
        if waitForRow {
            XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 5))
        }
    }
}
