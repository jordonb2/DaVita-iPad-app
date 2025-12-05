import Foundation

/// UserDefaults-backed admin-only settings.
enum AdminSettings {
    private static let prefix = "DaVita."
    private static let defaults = UserDefaults.standard

    private enum Keys {
        static let privacyScreenEnabled = "\(prefix)privacyScreenEnabled"
        static let exportScope = "\(prefix)defaultExportScope"
        static let autoLogoutSeconds = "\(prefix)autoLogoutSeconds"
    }

    /// Defaults to enabled (matches prior behavior).
    static var privacyScreenEnabled: Bool {
        get {
            if ProcessInfo.processInfo.arguments.contains("UI_TESTING") { return false }
            if defaults.object(forKey: Keys.privacyScreenEnabled) == nil { return true }
            return defaults.bool(forKey: Keys.privacyScreenEnabled)
        }
        set { defaults.set(newValue, forKey: Keys.privacyScreenEnabled) }
    }

    /// Default export scope for admin exports. Raw value persisted.
    static var defaultExportScopeRaw: Int {
        get { defaults.integer(forKey: Keys.exportScope) }
        set { defaults.set(newValue, forKey: Keys.exportScope) }
    }

    /// Admin auto-logout timeout in seconds. Returns nil if not set.
    static var autoLogoutSeconds: TimeInterval? {
        get {
            guard let value = defaults.object(forKey: Keys.autoLogoutSeconds) as? Double else { return nil }
            return value
        }
        set {
            if let newValue {
                defaults.set(newValue, forKey: Keys.autoLogoutSeconds)
            } else {
                defaults.removeObject(forKey: Keys.autoLogoutSeconds)
            }
        }
    }
}


