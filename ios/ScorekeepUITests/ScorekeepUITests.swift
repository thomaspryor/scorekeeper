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
        addName("LEO", in: app)

        let addToMaya = app.buttons["Add 1 to MAYA"]
        XCTAssertTrue(addToMaya.waitForExistence(timeout: 5))
        addToMaya.tap()
        addToMaya.tap()
        addToMaya.tap()
        XCTAssertTrue(app.staticTexts["MAYA score 3"].waitForExistence(timeout: 2))

        // Three quick taps are one undo step.
        app.buttons["Undo"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["MAYA score 0"].waitForExistence(timeout: 2))

        app.buttons["Add 1 to LEO"].tap()
        app.buttons["End game and show winner"].tap()
        XCTAssertTrue(app.staticTexts["Wins!"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["LEO"].exists)
        app.buttons["Back"].tap()
        XCTAssertTrue(app.staticTexts["LEO score 1"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func addName(_ name: String, in app: XCUIApplication) {
        let field = app.textFields["Player name"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        // Return submits the sheet (the keyboard's key is also labeled "Done").
        field.typeText(name + "\n")
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 5))
    }
}
