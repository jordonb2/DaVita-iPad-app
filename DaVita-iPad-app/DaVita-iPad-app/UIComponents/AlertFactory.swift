import UIKit

/// Centralized UIAlertController builders for consistent alerts.
enum AlertFactory {

    static func okAlert(title: String, message: String? = nil, onOK: (() -> Void)? = nil) -> UIAlertController {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in onOK?() })
        return alert
    }

    static func confirmAlert(title: String,
                             message: String?,
                             confirmTitle: String = "Yes",
                             cancelTitle: String = "Cancel",
                             isDestructive: Bool = true,
                             onConfirm: @escaping () -> Void) -> UIAlertController {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: cancelTitle, style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: confirmTitle, style: isDestructive ? .destructive : .default) { _ in
            onConfirm()
        })
        return alert
    }

    static func adminLoginAlert(onLogin: @escaping (_ username: String, _ password: String) -> Void) -> UIAlertController {
        let alert = UIAlertController(title: "Admin Login", message: "Enter credentials to view analytics.", preferredStyle: .alert)
        alert.addTextField { field in
            field.placeholder = "Username"
            field.autocapitalizationType = .none
        }
        alert.addTextField { field in
            field.placeholder = "Password"
            field.isSecureTextEntry = true
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Login", style: .default) { _ in
            let username = alert.textFields?.first?.text ?? ""
            let password = alert.textFields?.last?.text ?? ""
            onLogin(username, password)
        })
        return alert
    }
}

extension UIViewController {
    func presentErrorAlert(title: String = "Something went wrong", message: String? = nil) {
        let alert = AlertFactory.okAlert(title: title, message: message)
        present(alert, animated: true)
    }

    func present(appError: AppError) {
        let ui = appError.userFacing
        switch ui.style {
        case .toast:
            // Keep toasts short; show message if present, otherwise title.
            showToast(message: ui.message ?? ui.title)
        case .alert:
            presentErrorAlert(title: ui.title, message: ui.message)
        }
    }

    /// Simple, lightweight toast (no dependencies).
    func showToast(message: String, duration: TimeInterval = 2.0) {
        let label = PaddingLabel()
        label.text = message
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = UIFont.preferredFont(forTextStyle: .subheadline)
        label.textColor = .white
        label.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        label.layer.cornerRadius = 12
        label.clipsToBounds = true
        label.alpha = 0
        label.isAccessibilityElement = true
        label.accessibilityLabel = message

        view.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: view.layoutMarginsGuide.leadingAnchor),
            label.trailingAnchor.constraint(lessThanOrEqualTo: view.layoutMarginsGuide.trailingAnchor)
        ])

        UIView.animate(withDuration: 0.2) {
            label.alpha = 1
        }

        UIView.animate(withDuration: 0.25, delay: duration, options: [.curveEaseInOut]) {
            label.alpha = 0
        } completion: { _ in
            label.removeFromSuperview()
        }
    }
}

private final class PaddingLabel: UILabel {
    var insets = UIEdgeInsets(top: 10, left: 14, bottom: 10, right: 14)

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }

    override var intrinsicContentSize: CGSize {
        let s = super.intrinsicContentSize
        return CGSize(width: s.width + insets.left + insets.right,
                      height: s.height + insets.top + insets.bottom)
    }
}

