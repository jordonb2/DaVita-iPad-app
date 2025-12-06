import Foundation

/// UserDefaults-backed admin-only settings (kept here to ensure target inclusion).
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

/// Central app dependency container built once at the composition root.
struct AppDependencies {
    let coreDataStack: CoreDataStacking
    let adminSession: AdminSessioning
    let adminAuthenticator: AdminAuthenticating
    let adminInactivityTimeoutSeconds: TimeInterval
    let analyticsLogger: CheckInAnalyticsLogging

    // Domain services / repos
    let peopleRepo: PersonRepositorying
    let personService: PersonServicing

    // Providers / exports
    let makeTrendsProvider: () -> CheckInTrendsProviding
    let makeAnalyticsSummaryProvider: () -> CheckInAnalyticsSummaryProviding
    let makeExportService: () -> ExportServicing

    init() {
        let resolvedTimeout = AppDependencies.resolveAdminInactivityTimeoutSeconds(
            infoDictionary: Bundle.main.infoDictionary,
            environment: ProcessInfo.processInfo.environment
        )
        let coreDataStack: CoreDataStacking = CoreDataStack()
        let adminSession: AdminSessioning = AdminSession(defaultTimeoutSeconds: resolvedTimeout)
        let adminAuthenticator: AdminAuthenticating = AdminAuthenticator(credentialsProvider: DefaultAdminCredentialsProvider())
        let analyticsLogger: CheckInAnalyticsLogging = CheckInAnalyticsLogger(coreDataStack: coreDataStack)

        // Fire-and-forget integrity repair (background context).
        DataIntegrityService(coreDataStack: coreDataStack).runInBackground()

        let peopleRepo: PersonRepositorying = PersonRepository(context: coreDataStack.viewContext)
        let personService: PersonServicing = PersonService(coreDataStack: coreDataStack)
        let analyticsSummaryOptions = CheckInAnalyticsSummaryProvider.Options.dashboardDefault()

        self.coreDataStack = coreDataStack
        self.adminSession = adminSession
        self.adminAuthenticator = adminAuthenticator
        self.adminInactivityTimeoutSeconds = resolvedTimeout
        self.analyticsLogger = analyticsLogger

        self.peopleRepo = peopleRepo
        self.personService = personService
        self.makeTrendsProvider = { CheckInTrendsProvider(context: coreDataStack.viewContext) }
        self.makeAnalyticsSummaryProvider = { CheckInAnalyticsSummaryProvider(coreDataStack: coreDataStack, options: analyticsSummaryOptions) }
        self.makeExportService = { ExportService(context: coreDataStack.viewContext) }
    }

    private static func resolveAdminInactivityTimeoutSeconds(infoDictionary: [String: Any]?,
                                                             environment: [String: String]) -> TimeInterval {
        if let persisted = AdminSettings.autoLogoutSeconds {
            return max(AdminSession.minimumInactivityTimeoutSeconds, persisted)
        }
        if let envValue = environment["ADMIN_INACTIVITY_TIMEOUT_SECONDS"], let parsed = TimeInterval(envValue) {
            let safe = max(AdminSession.minimumInactivityTimeoutSeconds, parsed)
            return safe
        }

        if let plistValue = infoDictionary?["AdminInactivityTimeoutSeconds"] {
            if let number = plistValue as? NSNumber {
                return max(AdminSession.minimumInactivityTimeoutSeconds, number.doubleValue)
            }
            if let string = plistValue as? String, let parsed = TimeInterval(string) {
                return max(AdminSession.minimumInactivityTimeoutSeconds, parsed)
            }
        }

        return AdminSession.defaultInactivityTimeoutSeconds
    }
}


