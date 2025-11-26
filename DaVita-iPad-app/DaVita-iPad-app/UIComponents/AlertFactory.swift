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
