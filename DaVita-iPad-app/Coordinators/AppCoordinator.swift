import UIKit

/// Owns app start and wiring root navigation controller into routing.
final class AppCoordinator {
    private let window: UIWindow
    private let router: AppRouting
    private let coreDataStack: CoreDataStacking

    init(window: UIWindow,
         router: AppRouting,
         coreDataStack: CoreDataStacking) {
        self.window = window
        self.router = router
        self.coreDataStack = coreDataStack
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
            peopleList.viewModel = PeopleListViewModel(coreDataStack: coreDataStack)
        }

        window.rootViewController = rootNav
        window.makeKeyAndVisible()
    }
}
