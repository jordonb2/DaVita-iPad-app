import UIKit
import Foundation

/// Owns app start and wiring root navigation controller into routing.
@MainActor
final class AppCoordinator {
    private let window: UIWindow
    let dependencies: AppDependencies

    private lazy var router: AppRouting = {
        // Screen factories built here (composition root).
        let makeHistoryVC: (Person?) -> CheckInHistoryViewController = { [dependencies] person in
            let repo: CheckInRepository = CheckInRepository(context: dependencies.coreDataStack.viewContext)
            return CheckInHistoryViewController(person: person, checkInRepo: repo)
        }

        let makeTimelineVC: (Person) -> PatientTimelineViewController = { [dependencies] person in
            let repo: CheckInRepository = CheckInRepository(context: dependencies.coreDataStack.viewContext)
            let escalationStore: EscalationStateStoring = EscalationStateStore()
            return PatientTimelineViewController(person: person, checkInRepo: repo, escalationStore: escalationStore)
        }

        let makeAnalyticsVC: () -> AnalyticsViewController = { [dependencies] in
            AnalyticsViewController(
                adminSession: dependencies.adminSession,
                summaryProvider: dependencies.makeAnalyticsSummaryProvider(),
                exportService: dependencies.makeExportService(),
                historyViewControllerFactory: { makeHistoryVC(nil) },
                reminderManager: dependencies.smartReminderManager,
                digestManager: dependencies.adminAlertsDigestManager,
                defaultExportScope: AnalyticsViewController.ExportScope(rawValue: AdminSettings.defaultExportScopeRaw) ?? .all
            )
        }

        let peopleFlowFactory: (AppRouting) -> PeopleFlowCoordinating = { [dependencies] router in
            PeopleFlowCoordinator(
                router: router,
                makeHistoryViewController: { person in makeHistoryVC(person) },
                makeTimelineViewController: { person in makeTimelineVC(person) },
                makeTrendsViewController: { person in
                    PersonTrendsViewController(
                        person: person,
                        trendsProvider: dependencies.makeTrendsProvider()
                    )
                }
            )
        }

        return AppRouter(
            adminSession: dependencies.adminSession,
            adminAuthenticator: dependencies.adminAuthenticator,
            analyticsLogger: dependencies.analyticsLogger,
            guidanceProvider: dependencies.symptomGuidanceProvider,
            makeAnalyticsViewController: makeAnalyticsVC,
            peopleFlowCoordinatorFactory: peopleFlowFactory
        )
    }()

    init(window: UIWindow, dependencies: AppDependencies = AppDependencies()) {
        self.window = window
        self.dependencies = dependencies
    }

    func start() {
        let sb = UIStoryboard(name: "Main", bundle: nil)
        let initial = sb.instantiateInitialViewController()

        let rootNav: UINavigationController
        if let nav = initial as? UINavigationController {
            rootNav = nav
        } else if let vc = initial {
            rootNav = UINavigationController(rootViewController: vc)
        } else {
            rootNav = UINavigationController(rootViewController: PeopleListViewController())
        }

        router.rootNavigationController = rootNav

        // Inject dependencies into root people list if possible
        if let peopleList = rootNav.viewControllers.first(where: { $0 is PeopleListViewController }) as? PeopleListViewController {
            peopleList.router = router
            peopleList.viewModel = PeopleListViewModel(
                peopleRepo: dependencies.peopleRepo,
                personService: dependencies.personService
            )
        }

        window.rootViewController = rootNav
        window.makeKeyAndVisible()
    }
}
