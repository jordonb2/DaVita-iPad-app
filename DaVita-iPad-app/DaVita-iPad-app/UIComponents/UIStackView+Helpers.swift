import UIKit

extension UIStackView {
    /// Removes all arranged subviews and detaches them from the view hierarchy.
    ///
    /// This is the safest way to make "render" methods idempotent for stack-driven UIs.
    func removeAllArrangedSubviews() {
        let views = arrangedSubviews
        for v in views {
            removeArrangedSubview(v)
            v.removeFromSuperview()
        }
    }
}


