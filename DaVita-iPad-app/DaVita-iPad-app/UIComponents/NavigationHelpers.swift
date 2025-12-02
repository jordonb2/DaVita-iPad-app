import UIKit

/// Centralized navigation/presentation helpers to keep modal flows consistent.
enum NavigationHelpers {

    enum Modal {
        /// Standard modal presentation style for this app.
        ///
        /// Note: `.formSheet` is a good default for iPad; iPhone will adapt to `.pageSheet`/full-screen.
        static let presentationStyle: UIModalPresentationStyle = .formSheet

        /// Wrap a view controller in a navigation controller with consistent modal configuration.
        static func embedInNavigation(_ root: UIViewController,
                                     presentationStyle: UIModalPresentationStyle = Modal.presentationStyle,
                                     transitionStyle: UIModalTransitionStyle = .coverVertical,
                                     isModalInPresentation: Bool = true) -> UINavigationController {
            let nav = UINavigationController(rootViewController: root)
            nav.modalPresentationStyle = presentationStyle
            nav.modalTransitionStyle = transitionStyle
            nav.isModalInPresentation = isModalInPresentation
            return nav
        }
    }
}

extension UIViewController {
    /// Dismisses the nearest presenting modal navigation stack, falling back to normal dismissal.
    func dismissModalFlow(animated: Bool = true, completion: (() -> Void)? = nil) {
        if let nav = navigationController, nav.presentingViewController != nil {
            nav.dismiss(animated: animated, completion: completion)
        } else {
            dismiss(animated: animated, completion: completion)
        }
    }
}


