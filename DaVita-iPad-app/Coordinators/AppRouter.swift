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
    private let adminAuthenticator: AdminAuthenticating
    private let analyticsLogger: CheckInAnalyticsLogging
    private let makeAnalyticsViewController: () -> AnalyticsViewController
    private let peopleFlowCoordinatorFactory: (AppRouting) -> PeopleFlowCoordinating

    private lazy var peopleFlowCoordinator: PeopleFlowCoordinating = peopleFlowCoordinatorFactory(self)

    init(adminSession: AdminSessioning,
         adminAuthenticator: AdminAuthenticating,
         analyticsLogger: CheckInAnalyticsLogging,
         makeAnalyticsViewController: @escaping () -> AnalyticsViewController,
         peopleFlowCoordinatorFactory: @escaping (AppRouting) -> PeopleFlowCoordinating) {
        self.adminSession = adminSession
        self.adminAuthenticator = adminAuthenticator
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
        // Add-person is a primary flow and should present full-screen (matches prior behavior).
        let nav = NavigationHelpers.Modal.embedInNavigation(addVC, presentationStyle: .fullScreen, isModalInPresentation: true)
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
        let adminAuthenticator = self.adminAuthenticator

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

        if let remaining = adminAuthenticator.lockoutRemainingSeconds() {
            let message = "Too many failed attempts. Try again in \(self.formattedDuration(remaining))."
            let lockoutAlert = AlertFactory.okAlert(title: "Locked out", message: message)
            presentingVC.present(lockoutAlert, animated: true)
            return
        }

        let alert = AlertFactory.adminLoginAlert { [weak presentingVC] username, password in
            guard let presentingVC else { return }
            switch adminAuthenticator.authenticate(username: username, password: password) {
            case .success:
                adminSession.logIn()
                presentAnalytics()
            case .invalid(let attemptsRemaining):
                let message = "Incorrect username or password. \(attemptsRemaining) attempts left before lockout."
                let errorAlert = AlertFactory.okAlert(title: "Login failed", message: message)
                presentingVC.present(errorAlert, animated: true)
            case .rateLimited(let retryAfter):
                let message = "Too many attempts. Please wait \(self.formattedDuration(retryAfter)) before trying again."
                let errorAlert = AlertFactory.okAlert(title: "Slow down", message: message)
                presentingVC.present(errorAlert, animated: true)
            case .locked(let remaining):
                let message = "Account locked. Try again in \(self.formattedDuration(remaining))."
                let errorAlert = AlertFactory.okAlert(title: "Locked out", message: message)
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

    private func formattedDuration(_ seconds: TimeInterval) -> String {
        if seconds >= 60 {
            let minutes = Int(ceil(seconds / 60))
            return "\(minutes) minute\(minutes == 1 ? "" : "s")"
        } else {
            let secs = Int(ceil(seconds))
            return "\(secs) second\(secs == 1 ? "" : "s")"
        }
    }
}
