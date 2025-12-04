import XCTest

final class ExtendedFlowsUITests: XCTestCase {

    private func makeApp(arguments: [String] = ["UI_TESTING", "UI_TEST_SEED"], environment: [String: String] = [:]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments
        app.launchEnvironment = environment
        app.launch()
        return app
    }

    func testAdminAutoLogoutDismissesAnalytics() {
        // Shorten inactivity timeout to force auto-logout quickly.
        let app = makeApp(environment: ["ADMIN_INACTIVITY_TIMEOUT_SECONDS": "1"])

        // Seed: add a person, then cancel check-in.
        app.buttons["peopleList.add"].tap()
        let nameField = app.textFields["addEdit.fullName"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3))
        nameField.tap()
        nameField.typeText("AutoLogout Seed")
        app.buttons["addEdit.save"].tap()
        app.buttons["checkIn.cancel"].tap()

        // Login to analytics.
        app.buttons["peopleList.analytics"].tap()
        let username = app.alerts.textFields.element(boundBy: 0)
        XCTAssertTrue(username.waitForExistence(timeout: 3))
        username.tap()
        username.typeText("admin")
        let password = app.alerts.secureTextFields.element(boundBy: 0)
        password.tap()
        password.typeText("analytics")
        app.alerts.buttons["Login"].tap()

        XCTAssertTrue(app.navigationBars["Analytics"].waitForExistence(timeout: 3))

        // Wait for auto-logout to trigger and dismiss analytics.
        sleep(2)
        XCTAssertFalse(app.navigationBars["Analytics"].waitForExistence(timeout: 2))
    }

    func testPrivacyOverlayAppearsWhenBackgrounded() {
        // Do not pass UI_TESTING so privacy overlay remains enabled (default).
        let app = makeApp(arguments: [])

        // Ensure main list is visible.
        XCTAssertTrue(app.tables["peopleList.table"].waitForExistence(timeout: 3))

        // Send app to background and bring it back.
        XCUIDevice.shared.press(.home)
        sleep(1)
        app.activate()

        // Overlay should be present briefly after returning (blur view with label "Protected").
        let protectedLabel = app.staticTexts["Protected"]
        XCTAssertTrue(protectedLabel.waitForExistence(timeout: 3))
    }
}

