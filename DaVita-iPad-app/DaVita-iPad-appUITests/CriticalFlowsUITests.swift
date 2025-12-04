import XCTest

final class CriticalFlowsUITests: XCTestCase {

    private func makeApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["UI_TESTING", "UI_TEST_SEED"]
        app.launch()
        return app
    }

    func testAddPersonAndCompleteCheckIn() {
        let app = makeApp()

        // People list
        XCTAssertTrue(app.buttons["peopleList.add"].waitForExistence(timeout: 3))
        attachScreenshot(app, name: "people_list")

        // Add person
        app.buttons["peopleList.add"].tap()
        let nameField = app.textFields["addEdit.fullName"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3))
        nameField.tap()
        nameField.typeText("Alice Test")

        attachScreenshot(app, name: "add_edit_filled")

        // Save → Check-in survey
        let save = app.buttons["addEdit.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 2))
        save.tap()

        let pain = app.sliders["checkIn.pain"]
        XCTAssertTrue(pain.waitForExistence(timeout: 3))
        pain.adjust(toNormalizedSliderPosition: 0.5) // ~5/10

        // Segments are exposed as buttons via their labels
        app.buttons["Okay"].tap()
        app.buttons["Good"].tap()

        attachScreenshot(app, name: "checkin_filled")

        let submit = app.buttons["checkIn.submit"]
        XCTAssertTrue(submit.waitForExistence(timeout: 2))
        submit.tap()

        // Back to list
        XCTAssertTrue(app.tables["peopleList.table"].waitForExistence(timeout: 3))
        attachScreenshot(app, name: "people_list_after_add")

        XCTAssertTrue(app.staticTexts["Alice Test"].exists)
    }

    func testHistoryFlowFromAnalytics() {
        let app = makeApp()

        // Seed: create one person (skip check-in)
        app.buttons["peopleList.add"].tap()
        let nameField = app.textFields["addEdit.fullName"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3))
        nameField.tap()
        nameField.typeText("History Seed")
        app.buttons["addEdit.save"].tap()

        // Check-in screen: cancel (skip)
        let cancel = app.buttons["checkIn.cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 3))
        cancel.tap()

        // Open analytics (admin gate)
        let analytics = app.buttons["peopleList.analytics"]
        XCTAssertTrue(analytics.waitForExistence(timeout: 3))
        analytics.tap()

        // Admin login alert
        let username = app.alerts.textFields.element(boundBy: 0)
        XCTAssertTrue(username.waitForExistence(timeout: 3))
        username.tap()
        username.typeText("admin")

        let password = app.alerts.secureTextFields.element(boundBy: 0)
        password.tap()
        password.typeText("analytics")

        app.alerts.buttons["Login"].tap()

        // Analytics screen & history
        XCTAssertTrue(app.navigationBars["Analytics"].waitForExistence(timeout: 3))
        attachScreenshot(app, name: "analytics")

        app.buttons["View Visit History"].tap()
        XCTAssertTrue(app.navigationBars["Visit History"].waitForExistence(timeout: 3))
        attachScreenshot(app, name: "history")

        // At least one row (or "No check-ins yet") should be shown.
        XCTAssertTrue(app.tables.element.cells.count >= 1)
    }
}
