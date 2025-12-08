import XCTest
@testable import DaVita_iPad_app

final class TrendSharingPreferencesStoreTests: XCTestCase {

    func testNormalizeRecipientsDedupesAndCaps() {
        let suiteName = "TrendSharingPreferencesStoreTests"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let store = TrendSharingPreferencesStore(defaults: defaults)
        let normalized = store.normalizeRecipients(from: "Test@Example.com,TEST@example.com, bad, friend@home.org;\nteam@care.com, extra1@test.com, extra2@test.com, extra3@test.com, extra4@test.com, extra5@test.com, extra6@test.com, extra7@test.com, extra8@test.com, extra9@test.com")

        XCTAssertEqual(normalized.first, "test@example.com")
        XCTAssertEqual(Set(normalized).count, normalized.count)
        XCTAssertLessThanOrEqual(normalized.count, 10)
    }

    func testIsDueForSendUsesLastSentDate() {
        let suiteName = "TrendSharingPreferencesStoreTests_due"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let calendar = Calendar(identifier: .gregorian)
        let store = TrendSharingPreferencesStore(defaults: defaults, calendar: calendar)
        let lastMonth = calendar.date(byAdding: .day, value: -31, to: Date())
        let prefs = TrendSharingPreferences(isEnabled: true, recipients: ["a@test.com"], lastSentAt: lastMonth)

        XCTAssertTrue(store.isDueForSend(prefs, now: Date()))
    }
}

