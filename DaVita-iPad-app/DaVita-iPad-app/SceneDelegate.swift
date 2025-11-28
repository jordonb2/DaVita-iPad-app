import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    private var coordinator: AppCoordinator?

    private enum PrivacyScreen {
        static let userDefaultsKey = statingKey("privacyScreenEnabled")

        /// Defaults to enabled if the key hasn't been set.
        static var isEnabled: Bool {
            if UserDefaults.standard.object(forKey: userDefaultsKey) == nil { return true }
            return UserDefaults.standard.bool(forKey: userDefaultsKey)
        }

        /// Namespaced key helper to avoid collisions.
        private static func statingKey(_ key: String) -> String {
            "DaVita.\(key)"
        }
    }

    private var privacyOverlayView: UIView?

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
        hidePrivacyOverlay()
        AdminSession.shared.handleAppDidBecomeActive()
    }

    func sceneWillResignActive(_ scene: UIScene) {
        showPrivacyOverlayIfNeeded()
        AdminSession.shared.handleAppWillResignActive()
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // If the system is transitioning back, remove early to avoid a visible "flash".
        hidePrivacyOverlay()
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        showPrivacyOverlayIfNeeded()
    }

    func sceneDidDisconnect(_ scene: UIScene) {}

    @objc private func userDidInteract(_ recognizer: UILongPressGestureRecognizer) {
        // Only count the beginning of a touch sequence.
        guard recognizer.state == .began else { return }
        AdminSession.shared.recordActivity()
    }

    // MARK: - Privacy screen

    private func showPrivacyOverlayIfNeeded() {
        guard PrivacyScreen.isEnabled else { return }
        guard privacyOverlayView == nil else { return }
        guard let window else { return }

        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
        blur.translatesAutoresizingMaskIntoConstraints = false
        blur.isUserInteractionEnabled = false

        // Optional subtle redaction label.
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Protected"
        label.font = UIFont.preferredFont(forTextStyle: .headline)
        label.textColor = UIColor.secondaryLabel
        label.accessibilityLabel = "Screen content hidden"

        blur.contentView.addSubview(label)

        window.addSubview(blur)
        NSLayoutConstraint.activate([
            blur.leadingAnchor.constraint(equalTo: window.leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: window.trailingAnchor),
            blur.topAnchor.constraint(equalTo: window.topAnchor),
            blur.bottomAnchor.constraint(equalTo: window.bottomAnchor),

            label.centerXAnchor.constraint(equalTo: blur.contentView.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: blur.contentView.centerYAnchor)
        ])

        privacyOverlayView = blur
    }

    private func hidePrivacyOverlay() {
        privacyOverlayView?.removeFromSuperview()
        privacyOverlayView = nil
    }
}

extension SceneDelegate: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }
}
