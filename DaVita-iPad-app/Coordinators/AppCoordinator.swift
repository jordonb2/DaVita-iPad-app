import UIKit

/// Owns app start and wiring root navigation controller into routing.
final class AppCoordinator {
    private let window: UIWindow
    private let router: AppRouter

    init(window: UIWindow, router: AppRouter = .shared) {
        self.window = window
        self.router = router
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

        // Inject router into root people list if possible
        if let peopleList = rootNav.viewControllers.first as? PeopleListViewController {
            peopleList.router = router
        }

        window.rootViewController = rootNav
        window.makeKeyAndVisible()
    }
}
