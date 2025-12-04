import XCTest
@testable import DaVita_iPad_app

final class AdminAuthenticatorTests: XCTestCase {

    func testAuthenticateSuccessClearsFailures() {
        var now = Date()
        let auth = makeAuthenticator(now: { now })

        _ = auth.authenticate(username: "wrong", password: "creds")
        XCTAssertFalse(auth.isLockedOut)

        let success = auth.authenticate(username: "user", password: "pass")
        XCTAssertEqual(success, .success)
        XCTAssertFalse(auth.isLockedOut)
        XCTAssertNil(auth.lockoutRemainingSeconds())
    }

    func testRateLimitBlocksRapidAttempts() {
        var now = Date()
        let rateLimit = AdminAuthRateLimit(maxAttempts: 2, window: 60)
        let lockout = AdminAuthLockoutPolicy(maxFailures: 10, window: 15 * 60, duration: 5 * 60)
        let auth = makeAuthenticator(rateLimit: rateLimit, lockoutPolicy: lockout, now: { now })

        _ = auth.authenticate(username: "user", password: "bad")
        _ = auth.authenticate(username: "user", password: "stillbad")

        let third = auth.authenticate(username: "user", password: "bad again")
        switch third {
        case .rateLimited(let retryAfter):
            XCTAssertGreaterThanOrEqual(retryAfter, 58)
            XCTAssertLessThanOrEqual(retryAfter, 60)
        default:
            XCTFail("Expected rate limiting after exceeding attempts.")
        }

        now = now.addingTimeInterval(61)
        let afterWindow = auth.authenticate(username: "user", password: "wrong post window")
        switch afterWindow {
        case .invalid, .locked, .success:
            XCTAssertTrue(true)
        case .rateLimited:
            XCTFail("Should not remain rate limited after window elapsed.")
        }
    }

    func testLockoutAfterRepeatedFailuresAndRecovery() {
        var now = Date()
        let rateLimit = AdminAuthRateLimit(maxAttempts: 5, window: 60)
        let lockout = AdminAuthLockoutPolicy(maxFailures: 3, window: 300, duration: 120)
        let auth = makeAuthenticator(rateLimit: rateLimit, lockoutPolicy: lockout, now: { now })

        _ = auth.authenticate(username: "user", password: "bad1")
        _ = auth.authenticate(username: "user", password: "bad2")
        let third = auth.authenticate(username: "user", password: "bad3")

        switch third {
        case .locked(let remaining):
            XCTAssertGreaterThanOrEqual(remaining, 118)
            XCTAssertLessThanOrEqual(remaining, 120)
        default:
            XCTFail("Expected lockout on third failure.")
        }
        XCTAssertTrue(auth.isLockedOut)

        now = now.addingTimeInterval(121)
        XCTAssertNil(auth.lockoutRemainingSeconds())

        let recovered = auth.authenticate(username: "user", password: "pass")
        XCTAssertEqual(recovered, .success)
        XCTAssertFalse(auth.isLockedOut)
    }

    // MARK: - Helpers

    private func makeAuthenticator(rateLimit: AdminAuthRateLimit = .default,
                                   lockoutPolicy: AdminAuthLockoutPolicy = .default,
                                   now: @escaping () -> Date) -> AdminAuthenticator {
        let suiteName = "AdminAuthenticatorTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            fatalError("Failed to create UserDefaults suite for testing")
        }
        defaults.removePersistentDomain(forName: suiteName)

        let creds = AdminCredentials(
            usernameHashHex: "04f8996da763b7a969b1028ee3007569eaf3a635486ddab211d512c85b9df8fb", // "user"
            passwordHashHex: "d74ff0ee8da3b9806b18c877dbf29bbde50b5bd8e4dad7a3a725000feb82e8f1"  // "pass"
        )

        return AdminAuthenticator(
            credentials: creds,
            userDefaults: defaults,
            now: now,
            rateLimit: rateLimit,
            lockoutPolicy: lockoutPolicy
        )
    }
}

