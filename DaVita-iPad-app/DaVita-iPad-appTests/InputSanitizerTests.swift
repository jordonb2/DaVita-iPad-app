import XCTest
@testable import DaVita_iPad_app

final class InputSanitizerTests: XCTestCase {

    func testPersonNameCollapsesWhitespaceAndTrims() {
        let raw = "  Jane   Doe \n"
        let sanitized = InputSanitizer.personName(raw)
        XCTAssertEqual(sanitized, "Jane Doe")
    }

    func testNoteStripsControlCharactersAndCapsLength() {
        let raw = "Hello\u{0007}\nWorld"
        let sanitized = InputSanitizer.note(raw, max: 5)
        XCTAssertEqual(sanitized, "Hello")
    }

    func testSearchKeywordNormalizesEmptyToNil() {
        XCTAssertNil(InputSanitizer.searchKeyword("   "))
        XCTAssertNil(InputSanitizer.searchKeyword(nil))
    }
}

