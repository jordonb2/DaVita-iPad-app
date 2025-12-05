import UIKit
import CoreData
import Foundation

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    private var coordinator: AppCoordinator?
    private var adminSession: AdminSessioning?

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

        // Create coordinator (composition root). Dependencies are built inside `AppCoordinator`.
        let coordinator = AppCoordinator(window: window)
        self.coordinator = coordinator
        self.adminSession = coordinator.dependencies.adminSession

        // Install global touch recognizer to record admin activity without interfering with UI.
        window.addGestureRecognizer(inactivityRecognizer)

        // Configure admin inactivity handling.
        adminSession?.configureAutoLogout(inactivityTimeoutSeconds: coordinator.dependencies.adminInactivityTimeoutSeconds)

        coordinator.start()

        seedUITestDataIfNeeded(dependencies: coordinator.dependencies)
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        hidePrivacyOverlay()
        adminSession?.handleAppDidBecomeActive()
    }

    func sceneWillResignActive(_ scene: UIScene) {
        showPrivacyOverlayIfNeeded()
        adminSession?.handleAppWillResignActive()
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
        adminSession?.recordActivity()
    }

    // MARK: - Privacy screen

    private func showPrivacyOverlayIfNeeded() {
        guard AdminSettings.privacyScreenEnabled else { return }
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

    // MARK: - UI Test Seeding

    private func seedUITestDataIfNeeded(dependencies: AppDependencies) {
        guard ProcessInfo.processInfo.arguments.contains("UI_TEST_SEED") else { return }

        let context = dependencies.coreDataStack.viewContext
        context.performAndWait {
            // Clear existing data to keep seeds deterministic across runs.
            let personFetch: NSFetchRequest<Person> = Person.fetchRequest()
            if let people = try? context.fetch(personFetch) {
                for p in people { context.delete(p) }
            }

            let repo = PersonRepository(context: context)
            let checkInRepo = CheckInRepository(context: context)

            let now = Date()
            let p1 = repo.createPerson(name: "Seed One", gender: .male, dob: nil)
            let p2 = repo.createPerson(name: "Seed Two", gender: .female, dob: nil)

            _ = checkInRepo.createRecord(createdAt: now.addingTimeInterval(-3600), for: p1, data: PersonCheckInData(painLevel: 4, energyBucket: .okay, moodBucket: .neutral, symptoms: "fatigue", concerns: "diet", teamNote: nil))
            _ = checkInRepo.createRecord(createdAt: now.addingTimeInterval(-7200), for: p2, data: PersonCheckInData(painLevel: 7, energyBucket: .low, moodBucket: .sad, symptoms: "cramps", concerns: "sleep", teamNote: nil))

            do {
                try repo.save()
            } catch {
                assertionFailure("UI test seed save failed: \(error)")
            }
        }
    }
}

extension SceneDelegate: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }
}
