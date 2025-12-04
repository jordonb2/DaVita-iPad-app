import Foundation

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
        let adminAuthenticator: AdminAuthenticating = AdminAuthenticator()
        let analyticsLogger: CheckInAnalyticsLogging = CheckInAnalyticsLogger(coreDataStack: coreDataStack)

        // Fire-and-forget integrity repair (background context).
        DataIntegrityService(coreDataStack: coreDataStack).runInBackground()

        let peopleRepo: PersonRepositorying = PersonRepository(context: coreDataStack.viewContext)
        let personService: PersonServicing = PersonService(coreDataStack: coreDataStack)

        self.coreDataStack = coreDataStack
        self.adminSession = adminSession
        self.adminAuthenticator = adminAuthenticator
        self.adminInactivityTimeoutSeconds = resolvedTimeout
        self.analyticsLogger = analyticsLogger

        self.peopleRepo = peopleRepo
        self.personService = personService

        self.makeTrendsProvider = { CheckInTrendsProvider(context: coreDataStack.viewContext) }
        self.makeAnalyticsSummaryProvider = { CheckInAnalyticsSummaryProvider(context: coreDataStack.viewContext) }
        self.makeExportService = { ExportService(context: coreDataStack.viewContext) }
    }

    private static func resolveAdminInactivityTimeoutSeconds(infoDictionary: [String: Any]?,
                                                             environment: [String: String]) -> TimeInterval {
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


