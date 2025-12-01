import Foundation

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
