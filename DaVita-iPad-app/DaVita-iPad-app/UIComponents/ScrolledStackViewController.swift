import UIKit

/// Base class that provides a scroll view with a vertical content stack.
/// Subclasses add arranged subviews to `contentStackView`.
class ScrolledStackViewController: UIViewController {

    let scrollView = UIScrollView()
    let contentStackView = UIStackView()

    /// Override to customize stack spacing.
    var stackSpacing: CGFloat { UIFactory.Theme.Spacing.l }

    /// Override to customize content insets inside the scroll view.
    var contentInsets: UIEdgeInsets { UIEdgeInsets(top: UIFactory.Theme.Spacing.xxl, left: UIFactory.Theme.Spacing.xxl, bottom: UIFactory.Theme.Spacing.xxl, right: UIFactory.Theme.Spacing.xxl) }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureScrolledStackLayout()
    }

    /// Clears the scroll content stack so subclasses can safely re-render without duplicating UI.
    func resetContentStack() {
        contentStackView.removeAllArrangedSubviews()
    }

    private func configureScrolledStackLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        contentStackView.axis = .vertical
        contentStackView.spacing = stackSpacing
        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStackView)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: contentInsets.left),
            contentStackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -contentInsets.right),
            contentStackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: contentInsets.top),
            contentStackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -contentInsets.bottom),
            contentStackView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -(contentInsets.left + contentInsets.right))
        ])
    }
}


