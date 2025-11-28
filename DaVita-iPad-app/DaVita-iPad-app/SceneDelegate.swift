import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    private var coordinator: AppCoordinator?

    private lazy var inactivityRecognizer: UILongPressGestureRecognizer = {
        let gr = UILongPressGestureRecognizer(target: self, action: #selector(userDidInteract(_:)))
        gr.minimumPressDuration = 0
        gr.cancelsTouchesInView = false
        gr.delegate = self
        return gr
    }()

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        let window = UIWindow(windowScene: windowScene)
        self.window = window

        // Configure admin inactivity handling.
        AdminSession.shared.configureAutoLogout(inactivityTimeoutSeconds: AdminSession.defaultInactivityTimeoutSeconds)

        // Install global touch recognizer to record admin activity without interfering with UI.
        window.addGestureRecognizer(inactivityRecognizer)

        let coordinator = AppCoordinator(window: window)
        self.coordinator = coordinator
        coordinator.start()
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        AdminSession.shared.handleAppDidBecomeActive()
    }

    func sceneWillResignActive(_ scene: UIScene) {
        AdminSession.shared.handleAppWillResignActive()
    }

    func sceneDidDisconnect(_ scene: UIScene) {}
    func sceneWillEnterForeground(_ scene: UIScene) {}
    func sceneDidEnterBackground(_ scene: UIScene) {}

    @objc private func userDidInteract(_ recognizer: UILongPressGestureRecognizer) {
        // Only count the beginning of a touch sequence.
        guard recognizer.state == .began else { return }
        AdminSession.shared.recordActivity()
    }
}

extension SceneDelegate: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }
}
