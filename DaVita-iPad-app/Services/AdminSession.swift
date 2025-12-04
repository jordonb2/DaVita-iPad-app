import Foundation
import CryptoKit

// MARK: - Admin Authentication

protocol AdminAuthenticating: AnyObject {
    var isLockedOut: Bool { get }
    func lockoutRemainingSeconds() -> TimeInterval?
    func authenticate(username: String, password: String) -> AdminAuthResult
    func clearState()
}

enum AdminAuthResult: Equatable {
    case success
    case invalid(attemptsRemaining: Int)
    case rateLimited(retryAfter: TimeInterval)
    case locked(remaining: TimeInterval)
}

struct AdminCredentials {
    let usernameHash: Data
    let passwordHash: Data

    init(usernameHashHex: String, passwordHashHex: String) {
        self.usernameHash = Data(hexString: usernameHashHex)
        self.passwordHash = Data(hexString: passwordHashHex)
    }

    static let `default` = AdminCredentials(
        usernameHashHex: "8c6976e5b5410415bde908bd4dee15dfb167a9c873fc4bb8a81f6f2ab448a918",
        passwordHashHex: "65f98121a162a56ad8ee919ed9ea394b9eabd8714616acf30636c6092ee350b9"
    )
}

struct AdminAuthRateLimit {
    let maxAttempts: Int
    let window: TimeInterval

    static let `default` = AdminAuthRateLimit(maxAttempts: 5, window: 60) // 5 attempts per minute.
}

struct AdminAuthLockoutPolicy {
    let maxFailures: Int
    let window: TimeInterval
    let duration: TimeInterval

    static let `default` = AdminAuthLockoutPolicy(
        maxFailures: 8,
        window: 15 * 60, // 15-minute rolling window.
        duration: 15 * 60 // 15-minute lockout.
    )
}

/// Handles admin credential verification, rate limiting, and lockouts.
final class AdminAuthenticator: AdminAuthenticating {
    private struct State {
        var failedAttempts: [TimeInterval]
        var lockoutUntil: TimeInterval?
    }

    private let credentials: AdminCredentials
    private let defaults: UserDefaults
    private let now: () -> Date
    private let rateLimit: AdminAuthRateLimit
    private let lockoutPolicy: AdminAuthLockoutPolicy

    private let failedAttemptsKey = "AdminAuthenticator.failedAttempts"
    private let lockoutUntilKey = "AdminAuthenticator.lockoutUntil"

    init(credentials: AdminCredentials = .default,
         userDefaults: UserDefaults = .standard,
         now: @escaping () -> Date = { Date() },
         rateLimit: AdminAuthRateLimit = .default,
         lockoutPolicy: AdminAuthLockoutPolicy = .default) {
        self.credentials = credentials
        self.defaults = userDefaults
        self.now = now
        self.rateLimit = rateLimit
        self.lockoutPolicy = lockoutPolicy
    }

    var isLockedOut: Bool {
        lockoutRemainingSeconds() != nil
    }

    func lockoutRemainingSeconds() -> TimeInterval? {
        let current = now()
        var state = loadState()
        state.failedAttempts = pruneAttempts(state.failedAttempts, now: current)

        guard let until = state.lockoutUntil else { return nil }
        let remaining = until - current.timeIntervalSince1970
        if remaining <= 0 {
            state.lockoutUntil = nil
            save(state)
            return nil
        }

        save(state)
        return remaining
    }

    func authenticate(username: String, password: String) -> AdminAuthResult {
        let currentDate = now()
        var state = loadState()

        state.failedAttempts = pruneAttempts(state.failedAttempts, now: currentDate)

        if let remaining = remainingLockoutSeconds(from: state, now: currentDate) {
            save(state)
            return .locked(remaining: remaining)
        }

        let attemptsWithinRateWindow = failures(within: rateLimit.window, from: state, now: currentDate)
        if attemptsWithinRateWindow.count >= rateLimit.maxAttempts {
            let retryAfter = rateLimitRetryAfterSeconds(failures: attemptsWithinRateWindow, now: currentDate, window: rateLimit.window)
            save(state)
            return .rateLimited(retryAfter: retryAfter)
        }

        let normalizedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

        let usernameHash = sha256(normalizedUsername)
        let passwordHash = sha256(normalizedPassword)

        if timingSafeEquals(usernameHash, credentials.usernameHash) &&
            timingSafeEquals(passwordHash, credentials.passwordHash) {
            state.failedAttempts = []
            state.lockoutUntil = nil
            save(state)
            return .success
        }

        state.failedAttempts.append(currentDate.timeIntervalSince1970)
        state.failedAttempts = pruneAttempts(state.failedAttempts, now: currentDate)

        let failuresInLockoutWindow = failures(within: lockoutPolicy.window, from: state, now: currentDate)
        if failuresInLockoutWindow.count >= lockoutPolicy.maxFailures {
            let until = currentDate.addingTimeInterval(lockoutPolicy.duration).timeIntervalSince1970
            state.lockoutUntil = until
            save(state)
            return .locked(remaining: lockoutPolicy.duration)
        }

        let attemptsRemaining = max(lockoutPolicy.maxFailures - failuresInLockoutWindow.count, 0)
        save(state)
        return .invalid(attemptsRemaining: attemptsRemaining)
    }

    func clearState() {
        defaults.removeObject(forKey: failedAttemptsKey)
        defaults.removeObject(forKey: lockoutUntilKey)
    }

    // MARK: - Private

    private func loadState() -> State {
        let attempts = defaults.array(forKey: failedAttemptsKey) as? [TimeInterval] ?? []
        let lockoutUntil = defaults.object(forKey: lockoutUntilKey) as? TimeInterval
        return State(failedAttempts: attempts, lockoutUntil: lockoutUntil)
    }

    private func save(_ state: State) {
        defaults.set(state.failedAttempts, forKey: failedAttemptsKey)
        if let lockoutUntil = state.lockoutUntil {
            defaults.set(lockoutUntil, forKey: lockoutUntilKey)
        } else {
            defaults.removeObject(forKey: lockoutUntilKey)
        }
    }

    private func remainingLockoutSeconds(from state: State, now: Date) -> TimeInterval? {
        guard let until = state.lockoutUntil else { return nil }
        let remaining = until - now.timeIntervalSince1970
        return remaining > 0 ? remaining : nil
    }

    private func pruneAttempts(_ attempts: [TimeInterval], now: Date) -> [TimeInterval] {
        let window = max(rateLimit.window, lockoutPolicy.window)
        let cutoff = now.timeIntervalSince1970 - window
        return attempts.filter { $0 >= cutoff }
    }

    private func failures(within window: TimeInterval, from state: State, now: Date) -> [TimeInterval] {
        let cutoff = now.timeIntervalSince1970 - window
        return state.failedAttempts.filter { $0 >= cutoff }
    }

    private func rateLimitRetryAfterSeconds(failures: [TimeInterval], now: Date, window: TimeInterval) -> TimeInterval {
        guard let earliest = failures.min() else { return window }
        let elapsed = now.timeIntervalSince1970 - earliest
        return max(1, window - elapsed)
    }

    private func sha256(_ text: String) -> Data {
        let digest = SHA256.hash(data: Data(text.utf8))
        return Data(digest)
    }

    private func timingSafeEquals(_ lhs: Data, _ rhs: Data) -> Bool {
        guard lhs.count == rhs.count else { return false }
        var diff: UInt8 = 0
        for idx in 0..<lhs.count {
            diff |= lhs[idx] ^ rhs[idx]
        }
        return diff == 0
    }
}

private extension Data {
    init(hexString: String) {
        self.init()
        var buffer = [UInt8]()
        buffer.reserveCapacity(hexString.count / 2)

        var currentIndex = hexString.startIndex
        while currentIndex < hexString.endIndex {
            let nextIndex = hexString.index(currentIndex, offsetBy: 2)
            let byteString = hexString[currentIndex..<nextIndex]
            let num = UInt8(byteString, radix: 16) ?? 0
            buffer.append(num)
            currentIndex = nextIndex
        }
        self.append(contentsOf: buffer)
    }
}

protocol AdminSessioning: AnyObject {
    var isLoggedIn: Bool { get }

    func configureAutoLogout(inactivityTimeoutSeconds: TimeInterval)
    func logIn()
    func logOut()
    func recordActivity()
    func handleAppDidBecomeActive()
    func handleAppWillResignActive()
}

final class AdminSession: AdminSessioning {
    init() {}

    /// Default idle timeout for admin sessions.
    static let defaultInactivityTimeoutSeconds: TimeInterval = 5 * 60

    private(set) var isLoggedIn: Bool = false

    private var inactivityTimeoutSeconds: TimeInterval = AdminSession.defaultInactivityTimeoutSeconds
    private var lastActivityDate: Date = Date()
    private var inactivityTimer: Timer?

    func configureAutoLogout(inactivityTimeoutSeconds: TimeInterval = AdminSession.defaultInactivityTimeoutSeconds) {
        self.inactivityTimeoutSeconds = max(5, inactivityTimeoutSeconds)
        if isLoggedIn {
            recordActivity()
        }
    }

    func logIn() {
        isLoggedIn = true
        recordActivity()
        NotificationCenter.default.post(name: .adminSessionDidLogIn, object: nil)
    }

    func logOut() {
        stopInactivityTimer()
        isLoggedIn = false
        NotificationCenter.default.post(name: .adminSessionDidLogOut, object: nil)
    }

    /// Call this whenever the user interacts with the app.
    func recordActivity() {
        guard isLoggedIn else { return }
        lastActivityDate = Date()
        scheduleInactivityTimer()
    }

    /// Call from scene/app lifecycle when the app becomes active.
    func handleAppDidBecomeActive() {
        guard isLoggedIn else { return }
        let elapsed = Date().timeIntervalSince(lastActivityDate)
        if elapsed >= inactivityTimeoutSeconds {
            autoLogout()
        } else {
            // Ensure timer is aligned to remaining time.
            scheduleInactivityTimer()
        }
    }

    /// Call from scene/app lifecycle when the app resigns active.
    func handleAppWillResignActive() {
        // Timers do not reliably fire in the background; we'll enforce on resume.
        stopInactivityTimer()
    }

    // MARK: - Private

    private func scheduleInactivityTimer() {
        stopInactivityTimer()
        let remaining = max(0, inactivityTimeoutSeconds - Date().timeIntervalSince(lastActivityDate))
        inactivityTimer = Timer.scheduledTimer(withTimeInterval: remaining, repeats: false) { [weak self] _ in
            self?.autoLogoutIfStillInactive()
        }
    }

    private func stopInactivityTimer() {
        inactivityTimer?.invalidate()
        inactivityTimer = nil
    }

    private func autoLogoutIfStillInactive() {
        guard isLoggedIn else { return }
        let elapsed = Date().timeIntervalSince(lastActivityDate)
        if elapsed >= inactivityTimeoutSeconds {
            autoLogout()
        } else {
            scheduleInactivityTimer()
        }
    }

    private func autoLogout() {
        stopInactivityTimer()
        isLoggedIn = false
        NotificationCenter.default.post(name: .adminSessionDidAutoLogout, object: nil)
    }
}

extension Notification.Name {
    static let adminSessionDidLogIn = Notification.Name("AdminSession.didLogIn")
    static let adminSessionDidLogOut = Notification.Name("AdminSession.didLogOut")
    static let adminSessionDidAutoLogout = Notification.Name("AdminSession.didAutoLogout")
}
