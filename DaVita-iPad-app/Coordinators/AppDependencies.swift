import Foundation

/// Central app dependency container built once at the composition root.
struct AppDependencies {
    let coreDataStack: CoreDataStacking
    let adminSession: AdminSessioning
    let adminAuthenticator: AdminAuthenticating
    let analyticsLogger: CheckInAnalyticsLogging

    // Domain services / repos
    let peopleRepo: PersonRepositorying
    let personService: PersonServicing

    // Providers / exports
    let makeTrendsProvider: () -> CheckInTrendsProviding
    let makeAnalyticsSummaryProvider: () -> CheckInAnalyticsSummaryProviding
    let makeExportService: () -> ExportServicing

    init() {
        let coreDataStack: CoreDataStacking = CoreDataStack()
        let adminSession: AdminSessioning = AdminSession()
        let adminAuthenticator: AdminAuthenticating = AdminAuthenticator()
        let analyticsLogger: CheckInAnalyticsLogging = CheckInAnalyticsLogger(coreDataStack: coreDataStack)

        // Fire-and-forget integrity repair (background context).
        DataIntegrityService(coreDataStack: coreDataStack).runInBackground()

        let peopleRepo: PersonRepositorying = PersonRepository(context: coreDataStack.viewContext)
        let personService: PersonServicing = PersonService(coreDataStack: coreDataStack)

        self.coreDataStack = coreDataStack
        self.adminSession = adminSession
        self.adminAuthenticator = adminAuthenticator
        self.analyticsLogger = analyticsLogger

        self.peopleRepo = peopleRepo
        self.personService = personService

        self.makeTrendsProvider = { CheckInTrendsProvider(context: coreDataStack.viewContext) }
        self.makeAnalyticsSummaryProvider = { CheckInAnalyticsSummaryProvider(context: coreDataStack.viewContext) }
        self.makeExportService = { ExportService(context: coreDataStack.viewContext) }
    }
}


