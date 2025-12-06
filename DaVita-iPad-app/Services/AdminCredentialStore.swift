import Foundation
import Security

/// Keychain-backed admin credential storage (hash-only).
/// Stores SHA-256 hex strings for username/password; no plaintext persisted.
enum AdminCredentialStore {
    private static let service = "DaVita.AdminCredentials"
    private static let accountUsername = "admin.usernameHash"
    private static let accountPassword = "admin.passwordHash"

    /// Returns stored hashes if present; otherwise nil.
    static func load() -> (usernameHashHex: String, passwordHashHex: String)? {
        guard
            let username = read(account: accountUsername),
            let password = read(account: accountPassword)
        else { return nil }
        return (username, password)
    }

    /// Persists new credential hashes (hex). Call with pre-hashed values only.
    static func save(usernameHashHex: String, passwordHashHex: String) {
        write(account: accountUsername, value: usernameHashHex)
        write(account: accountPassword, value: passwordHashHex)
    }

    /// Removes stored credentials; defaults will be used.
    static func clear() {
        delete(account: accountUsername)
        delete(account: accountPassword)
    }

    // MARK: - Keychain helpers

    private static func read(account: String) -> String? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func write(account: String, value: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }

    private static func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}


