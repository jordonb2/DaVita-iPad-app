import UIKit

protocol AppRouting: AnyObject {
    var rootNavigationController: UINavigationController? { get set }

    func showAddPerson(from presentingVC: UIViewController,
                       onSave: @escaping (String, Date, String, PersonCheckInData) -> Void)
    func showEditPerson(_ person: Person, from presentingVC: UIViewController,
                        onSave: @escaping (String, Date, String, PersonCheckInData) -> Void)

    /// Deeper people flow entrypoint.
    func showPersonDetail(_ person: Person,
                          from presentingVC: UIViewController,
                          onUpdate: @escaping (Person, String, Date, String, PersonCheckInData) -> Void)

    func showAnalytics(from presentingVC: UIViewController)
    func presentCheckIn(from presentingVC: UIViewController,
                        onComplete: @escaping (PersonCheckInData) -> Void,
                        onSkip: @escaping () -> Void)
}

/// Lightweight router that owns VC construction and presentation.
final class AppRouter: AppRouting {
    weak var rootNavigationController: UINavigationController?

    private let coreDataStack: CoreDataStacking
    private let adminSession: AdminSessioning
    private let analyticsLogger: CheckInAnalyticsLogging

    private lazy var peopleFlowCoordinator: PeopleFlowCoordinating = PeopleFlowCoordinator(
        router: self,
        coreDataStack: coreDataStack
    )

    init(coreDataStack: CoreDataStacking,
         adminSession: AdminSessioning,
         analyticsLogger: CheckInAnalyticsLogging) {
        self.coreDataStack = coreDataStack
        self.adminSession = adminSession
        self.analyticsLogger = analyticsLogger
    }

    private var mainStoryboard: UIStoryboard {
        UIStoryboard(name: "Main", bundle: nil)
    }

    func showAddPerson(from presentingVC: UIViewController,
                       onSave: @escaping (String, Date, String, PersonCheckInData) -> Void) {
        guard let addVC = mainStoryboard.instantiateViewController(withIdentifier: "AddEditPersonVC") as? AddEditPersonViewController else { return }
        addVC.router = self
        addVC.onSave = onSave
        let nav = UINavigationController(rootViewController: addVC)
        nav.modalPresentationStyle = .fullScreen
        nav.modalTransitionStyle = .coverVertical
        presentingVC.present(nav, animated: true)
    }

    func showEditPerson(_ person: Person, from presentingVC: UIViewController,
                        onSave: @escaping (String, Date, String, PersonCheckInData) -> Void) {
        guard let addVC = mainStoryboard.instantiateViewController(withIdentifier: "AddEditPersonVC") as? AddEditPersonViewController else { return }
        addVC.personToEdit = person
        addVC.router = self
        addVC.onSave = onSave
        let nav = UINavigationController(rootViewController: addVC)
        nav.modalPresentationStyle = .formSheet
        presentingVC.present(nav, animated: true)
    }

    func showPersonDetail(_ person: Person,
                          from presentingVC: UIViewController,
                          onUpdate: @escaping (Person, String, Date, String, PersonCheckInData) -> Void) {
        peopleFlowCoordinator.showPersonDetail(person, from: presentingVC, onUpdate: onUpdate)
    }

    func showAnalytics(from presentingVC: UIViewController) {
        let coreDataStack = self.coreDataStack
        let adminSession = self.adminSession
        let summaryProvider = CheckInAnalyticsSummaryProvider(context: coreDataStack.viewContext)
        let exportService = ExportService(context: coreDataStack.viewContext)

        let presentAnalytics: () -> Void = { [weak presentingVC] in
            guard let presentingVC else { return }

            let analyticsVC = AnalyticsViewController(
                adminSession: adminSession,
                summaryProvider: summaryProvider,
                exportService: exportService,
                historyViewControllerFactory: {
                    CheckInHistoryViewController(person: nil, context: coreDataStack.viewContext)
                }
            )
            analyticsVC.onLogoutConfirmed = { [weak presentingVC] in
                adminSession.logOut()
                presentingVC?.dismiss(animated: true)
            }

            let nav = UINavigationController(rootViewController: analyticsVC)
            nav.modalPresentationStyle = .formSheet
            presentingVC.present(nav, animated: true)
        }

        if adminSession.isLoggedIn {
            presentAnalytics()
            return
        }

        let alert = AlertFactory.adminLoginAlert { [weak presentingVC] username, password in
            guard let presentingVC else { return }
            if username == "admin" && password == "analytics" {
                adminSession.logIn()
                presentAnalytics()
            } else {
                let errorAlert = AlertFactory.okAlert(title: "Login failed", message: "Incorrect username or password.")
                presentingVC.present(errorAlert, animated: true)
            }
        }
        presentingVC.present(alert, animated: true)
    }

    func presentCheckIn(from presentingVC: UIViewController,
                        onComplete: @escaping (PersonCheckInData) -> Void,
                        onSkip: @escaping () -> Void) {
        let checkInVC = CheckInJourneyViewController(analyticsLogger: analyticsLogger)
        checkInVC.onComplete = onComplete
        checkInVC.onSkip = onSkip
        let nav = UINavigationController(rootViewController: checkInVC)
        nav.modalPresentationStyle = .formSheet
        presentingVC.present(nav, animated: true)
    }
}
