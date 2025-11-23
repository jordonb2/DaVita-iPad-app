import Foundation

final class AdminSession {
    static let shared = AdminSession()
    private init() {}

    private(set) var isLoggedIn: Bool = false

    func logIn() {
        isLoggedIn = true
    }

    func logOut() {
        isLoggedIn = false
    }
}
