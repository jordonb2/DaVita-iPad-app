import UIKit

protocol AppRouting: AnyObject {
    var rootNavigationController: UINavigationController? { get set }

    func showAddPerson(from presentingVC: UIViewController,
                       onSave: @escaping (String, Date, Gender?, PersonCheckInData) -> Void)
    func showEditPerson(_ person: Person, from presentingVC: UIViewController,
                        onSave: @escaping (String, Date, Gender?, PersonCheckInData) -> Void)

    /// Deeper people flow entrypoint.
    func showPersonDetail(_ person: Person,
                          from presentingVC: UIViewController,
                          onUpdate: @escaping (Person, String, Date, Gender?, PersonCheckInData) -> Void)

    func showAnalytics(from presentingVC: UIViewController)
    func presentCheckIn(from presentingVC: UIViewController,
                        onComplete: @escaping (PersonCheckInData) -> Void,
                        onSkip: @escaping () -> Void)
}

/// Lightweight router that owns VC construction and presentation.
final class AppRouter: AppRouting {
    weak var rootNavigationController: UINavigationController?

    private let adminSession: AdminSessioning
    private let analyticsLogger: CheckInAnalyticsLogging
    private let makeAnalyticsViewController: () -> AnalyticsViewController
    private let peopleFlowCoordinatorFactory: (AppRouting) -> PeopleFlowCoordinating

    private lazy var peopleFlowCoordinator: PeopleFlowCoordinating = peopleFlowCoordinatorFactory(self)

    init(adminSession: AdminSessioning,
         analyticsLogger: CheckInAnalyticsLogging,
         makeAnalyticsViewController: @escaping () -> AnalyticsViewController,
         peopleFlowCoordinatorFactory: @escaping (AppRouting) -> PeopleFlowCoordinating) {
        self.adminSession = adminSession
        self.analyticsLogger = analyticsLogger
        self.makeAnalyticsViewController = makeAnalyticsViewController
        self.peopleFlowCoordinatorFactory = peopleFlowCoordinatorFactory
    }

    private var mainStoryboard: UIStoryboard {
        UIStoryboard(name: "Main", bundle: nil)
    }

    func showAddPerson(from presentingVC: UIViewController,
                       onSave: @escaping (String, Date, Gender?, PersonCheckInData) -> Void) {
        guard let addVC = mainStoryboard.instantiateViewController(withIdentifier: "AddEditPersonVC") as? AddEditPersonViewController else { return }
        addVC.router = self
        addVC.onSave = onSave
        let nav = NavigationHelpers.Modal.embedInNavigation(addVC)
        presentingVC.present(nav, animated: true)
    }

    func showEditPerson(_ person: Person, from presentingVC: UIViewController,
                        onSave: @escaping (String, Date, Gender?, PersonCheckInData) -> Void) {
        guard let addVC = mainStoryboard.instantiateViewController(withIdentifier: "AddEditPersonVC") as? AddEditPersonViewController else { return }
        addVC.personToEdit = person
        addVC.router = self
        addVC.onSave = onSave
        let nav = NavigationHelpers.Modal.embedInNavigation(addVC)
        presentingVC.present(nav, animated: true)
    }

    func showPersonDetail(_ person: Person,
                          from presentingVC: UIViewController,
                          onUpdate: @escaping (Person, String, Date, Gender?, PersonCheckInData) -> Void) {
        peopleFlowCoordinator.showPersonDetail(person, from: presentingVC, onUpdate: onUpdate)
    }

    func showAnalytics(from presentingVC: UIViewController) {
        let adminSession = self.adminSession

        let presentAnalytics: () -> Void = { [weak presentingVC] in
            guard let presentingVC else { return }

            let analyticsVC = self.makeAnalyticsViewController()
            analyticsVC.onLogoutConfirmed = { [weak presentingVC] in
                adminSession.logOut()
                presentingVC?.dismiss(animated: true)
            }

            let nav = NavigationHelpers.Modal.embedInNavigation(analyticsVC, isModalInPresentation: true)
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
        // Ensure the check-in modal consistently dismisses before notifying the caller.
        checkInVC.onComplete = { [weak presentingVC] data in
            presentingVC?.dismiss(animated: true) {
                onComplete(data)
            }
        }
        checkInVC.onSkip = { [weak presentingVC] in
            presentingVC?.dismiss(animated: true) {
                onSkip()
            }
        }

        let nav = NavigationHelpers.Modal.embedInNavigation(checkInVC, isModalInPresentation: true)
        presentingVC.present(nav, animated: true)
    }
}
