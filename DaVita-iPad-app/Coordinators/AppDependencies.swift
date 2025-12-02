import Foundation

/// Central app dependency container built once at the composition root.
struct AppDependencies {
    let coreDataStack: CoreDataStacking
    let adminSession: AdminSessioning
    let analyticsLogger: CheckInAnalyticsLogging

    // Domain services / repos
    let peopleRepo: PersonRepositorying
    let checkInService: CheckInServicing
    let personService: PersonServicing

    // Providers / exports
    let makeTrendsProvider: () -> CheckInTrendsProviding
    let makeAnalyticsSummaryProvider: () -> CheckInAnalyticsSummaryProviding
    let makeExportService: () -> ExportServicing

    init() {
        let coreDataStack: CoreDataStacking = CoreDataStack()
        let adminSession: AdminSessioning = AdminSession()
        let analyticsLogger: CheckInAnalyticsLogging = CheckInAnalyticsLogger(context: coreDataStack.viewContext)

        let peopleRepo: PersonRepositorying = PersonRepository(context: coreDataStack.viewContext)
        let checkInService: CheckInServicing = CheckInService(coreDataStack: coreDataStack)
        let personService: PersonServicing = PersonService(peopleRepo: peopleRepo, checkInService: checkInService)

        self.coreDataStack = coreDataStack
        self.adminSession = adminSession
        self.analyticsLogger = analyticsLogger

        self.peopleRepo = peopleRepo
        self.checkInService = checkInService
        self.personService = personService

        self.makeTrendsProvider = { CheckInTrendsProvider(context: coreDataStack.viewContext) }
        self.makeAnalyticsSummaryProvider = { CheckInAnalyticsSummaryProvider(context: coreDataStack.viewContext) }
        self.makeExportService = { ExportService(context: coreDataStack.viewContext) }
    }
}


