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

    func testPrivacyOverlayCoversModalWhenBackgrounded() {
        let app = makeApp(arguments: [])

        // Present add/edit modal.
        app.buttons["peopleList.add"].tap()
        XCTAssertTrue(app.textFields["addEdit.fullName"].waitForExistence(timeout: 3))

        // Background while modal is up.
        XCUIDevice.shared.press(.home)
        sleep(1)
        app.activate()

        // Overlay should still be visible.
        let protectedLabel = app.staticTexts["Protected"]
        XCTAssertTrue(protectedLabel.waitForExistence(timeout: 3))

        // Dismiss modal to clean up.
        app.buttons["Cancel"].tap()
    }

    func testAnalyticsEmptyStateShowsVoiceOverLabels() {
        // Launch without seed data so analytics has no events.
        let app = makeApp(arguments: ["UI_TESTING"])

        // Open analytics (admin gate).
        let analytics = app.buttons["peopleList.analytics"]
        XCTAssertTrue(analytics.waitForExistence(timeout: 3))
        XCTAssertEqual(analytics.label, "Analytics")
        analytics.tap()

        let username = app.alerts.textFields.element(boundBy: 0)
        XCTAssertTrue(username.waitForExistence(timeout: 3))
        username.tap()
        username.typeText("admin")

        let password = app.alerts.secureTextFields.element(boundBy: 0)
        password.tap()
        password.typeText("analytics")
        app.alerts.buttons["Login"].tap()

        // Empty state should be visible with readable text for VoiceOver.
        let emptyTitle = app.staticTexts["No analytics yet"]
        XCTAssertTrue(emptyTitle.waitForExistence(timeout: 3))
        let refresh = app.buttons["Refresh"]
        XCTAssertTrue(refresh.exists)
    }

    func testVoiceOverLabelsOnPeopleListPrimaryControls() {
        let app = makeApp(arguments: ["UI_TESTING", "UI_TEST_SEED"])

        // Primary actions should have stable accessibility labels.
        let add = app.buttons["peopleList.add"]
        XCTAssertTrue(add.waitForExistence(timeout: 3))
        XCTAssertEqual(add.label, "Add")

        let analytics = app.buttons["peopleList.analytics"]
        XCTAssertTrue(analytics.exists)
        XCTAssertEqual(analytics.label, "Analytics")

        let table = app.tables["peopleList.table"]
        XCTAssertTrue(table.exists)
    }
}

