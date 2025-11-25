import UIKit

protocol AppRouting: AnyObject {
    func showAddPerson(from presentingVC: UIViewController,
                       onSave: @escaping (String, Date, String, PersonCheckInData) -> Void)
    func showEditPerson(_ person: Person, from presentingVC: UIViewController,
                        onSave: @escaping (String, Date, String, PersonCheckInData) -> Void)
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

    func showAnalytics(from presentingVC: UIViewController) {
        let analyticsVC = AnalyticsViewController()
        analyticsVC.onLogoutConfirmed = { [weak self, weak presentingVC] in
            AdminSession.shared.logOut()
            presentingVC?.dismiss(animated: true)
            // no-op for router
            _ = self
        }
        let nav = UINavigationController(rootViewController: analyticsVC)
        nav.modalPresentationStyle = .formSheet
        presentingVC.present(nav, animated: true)
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
