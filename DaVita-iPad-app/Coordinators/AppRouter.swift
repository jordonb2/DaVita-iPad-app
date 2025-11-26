import UIKit

protocol AppRouting: AnyObject {
    var rootNavigationController: UINavigationController? { get }

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
    static let shared = AppRouter()
    private init() {}

    weak var rootNavigationController: UINavigationController?
    private lazy var peopleFlowCoordinator: PeopleFlowCoordinating = PeopleFlowCoordinator(router: self)

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
        let presentAnalytics: () -> Void = { [weak self, weak presentingVC] in
            guard let presentingVC else { return }
            let analyticsVC = AnalyticsViewController()
            analyticsVC.onLogoutConfirmed = { [weak self, weak presentingVC] in
                AdminSession.shared.logOut()
                presentingVC?.dismiss(animated: true)
                _ = self
            }
            let nav = UINavigationController(rootViewController: analyticsVC)
            nav.modalPresentationStyle = .formSheet
            presentingVC.present(nav, animated: true)
        }

        if AdminSession.shared.isLoggedIn {
            presentAnalytics()
            return
        }

        let alert = AlertFactory.adminLoginAlert { [weak presentingVC] username, password in
            guard let presentingVC else { return }
            if username == "admin" && password == "analytics" {
                AdminSession.shared.logIn()
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
        let checkInVC = CheckInJourneyViewController()
        checkInVC.onComplete = onComplete
        checkInVC.onSkip = onSkip
        let nav = UINavigationController(rootViewController: checkInVC)
        nav.modalPresentationStyle = .formSheet
        presentingVC.present(nav, animated: true)
    }
}
