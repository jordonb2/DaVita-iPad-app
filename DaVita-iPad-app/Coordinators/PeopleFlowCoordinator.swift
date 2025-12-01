import UIKit
import CoreData

protocol PeopleFlowCoordinating: AnyObject {
    func showPersonDetail(_ person: Person,
                          from presentingVC: UIViewController,
                          onUpdate: @escaping (Person, String, Date, String, PersonCheckInData) -> Void)
    func showPersonHistory(_ person: Person, from presentingVC: UIViewController)
    func showPersonTrends(_ person: Person, from presentingVC: UIViewController)
}

/// Owns deeper people-related flows: person detail and history drill-ins.
final class PeopleFlowCoordinator: PeopleFlowCoordinating {
    private weak var router: AppRouting?
    private let coreDataStack: CoreDataStacking

    init(router: AppRouting, coreDataStack: CoreDataStacking) {
        self.router = router
        self.coreDataStack = coreDataStack
    }

    private func navigationController(from presentingVC: UIViewController) -> UINavigationController? {
        if let nav = presentingVC.navigationController { return nav }
        return router?.rootNavigationController
    }

    func showPersonDetail(_ person: Person,
                          from presentingVC: UIViewController,
                          onUpdate: @escaping (Person, String, Date, String, PersonCheckInData) -> Void) {
        guard let nav = navigationController(from: presentingVC) else { return }

        let detailVC = PersonDetailViewController(person: person)
        detailVC.onEditTapped = { [weak self, weak presentingVC] person in
            guard let self, let presentingVC else { return }
            self.router?.showEditPerson(person, from: presentingVC) { name, dob, gender, checkInData in
                onUpdate(person, name, dob, gender, checkInData)
            }
        }
        detailVC.onHistoryTapped = { [weak self, weak presentingVC] person in
            guard let self, let presentingVC else { return }
            self.showPersonHistory(person, from: presentingVC)
        }

        detailVC.onTrendsTapped = { [weak self, weak presentingVC] person in
            guard let self, let presentingVC else { return }
            self.showPersonTrends(person, from: presentingVC)
        }

        nav.pushViewController(detailVC, animated: true)
    }

    func showPersonHistory(_ person: Person, from presentingVC: UIViewController) {
        guard let nav = navigationController(from: presentingVC) else { return }
        let vc = CheckInHistoryViewController(person: person, context: coreDataStack.viewContext)
        nav.pushViewController(vc, animated: true)
    }

    func showPersonTrends(_ person: Person, from presentingVC: UIViewController) {
        guard let nav = navigationController(from: presentingVC) else { return }
        let provider = CheckInTrendsProvider(context: coreDataStack.viewContext)
        let vc = PersonTrendsViewController(person: person, trendsProvider: provider)
        nav.pushViewController(vc, animated: true)
    }
}
