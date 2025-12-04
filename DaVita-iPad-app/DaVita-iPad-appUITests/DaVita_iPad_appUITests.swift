import XCTest

final class DaVita_iPad_appUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }
}

extension XCTestCase {
    /// Standardized screenshot attachment with consistent naming and retention.
    func attachScreenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "screen_\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
