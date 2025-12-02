import UIKit

/// Reusable state component for empty/error/loading screens and table backgrounds.
final class StateView: UIView {

    enum Kind {
        case empty
        case error
        case loading
    }

    struct Model {
        let kind: Kind
        let title: String
        let message: String?
        let systemImageName: String?
        let actionTitle: String?
        let onAction: (() -> Void)?

        init(kind: Kind,
             title: String,
             message: String? = nil,
             systemImageName: String? = nil,
             actionTitle: String? = nil,
             onAction: (() -> Void)? = nil) {
            self.kind = kind
            self.title = title
            self.message = message
            self.systemImageName = systemImageName
            self.actionTitle = actionTitle
            self.onAction = onAction
        }
    }

    private let imageView = UIImageView()
    private let titleLabel = UILabel()
    private let messageLabel = UILabel()
    private let actionButton = UIButton(type: .system)
    private let activity = UIActivityIndicatorView(style: .medium)

    private var onAction: (() -> Void)?

    init(model: Model) {
        super.init(frame: .zero)
        configureUI()
        apply(model)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(_ model: Model) {
        onAction = model.onAction

        titleLabel.text = model.title
        messageLabel.text = model.message

        if let name = model.systemImageName {
            imageView.image = UIImage(systemName: name)
            imageView.isHidden = false
        } else {
            imageView.image = nil
            imageView.isHidden = true
        }

        if let actionTitle = model.actionTitle {
            actionButton.setTitle(actionTitle, for: .normal)
            actionButton.isHidden = false
        } else {
            actionButton.setTitle(nil, for: .normal)
            actionButton.isHidden = true
        }

        switch model.kind {
        case .loading:
            activity.startAnimating()
            activity.isHidden = false
        case .empty, .error:
            activity.stopAnimating()
            activity.isHidden = true
        }

        // Accessibility
        isAccessibilityElement = true
        accessibilityTraits = [.staticText]
        accessibilityLabel = model.title
        accessibilityValue = model.message
    }

    private func configureUI() {
        backgroundColor = .clear

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = UIFactory.Theme.Color.textSecondary

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.numberOfLines = 0
        titleLabel.textAlignment = .center
        UIFactory.Theme.Typography.apply(.headline, to: titleLabel)
        titleLabel.textColor = UIFactory.Theme.Color.textPrimary

        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.numberOfLines = 0
        messageLabel.textAlignment = .center
        messageLabel.font = UIFactory.Theme.Typography.font(.subheadline)
        messageLabel.adjustsFontForContentSizeCategory = true
        messageLabel.textColor = UIFactory.Theme.Color.textSecondary

        actionButton.translatesAutoresizingMaskIntoConstraints = false
        actionButton.titleLabel?.font = UIFactory.Theme.Typography.font(.button)
        actionButton.titleLabel?.adjustsFontForContentSizeCategory = true

        activity.translatesAutoresizingMaskIntoConstraints = false
        activity.hidesWhenStopped = true

        let stack = UIStackView(arrangedSubviews: [imageView, titleLabel, messageLabel, activity, actionButton])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = UIFactory.Theme.Spacing.m

        // Let labels expand horizontally.
        titleLabel.widthAnchor.constraint(lessThanOrEqualTo: stack.widthAnchor).isActive = true
        messageLabel.widthAnchor.constraint(lessThanOrEqualTo: stack.widthAnchor).isActive = true

        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: layoutMarginsGuide.trailingAnchor),

            imageView.heightAnchor.constraint(equalToConstant: 44),
            imageView.widthAnchor.constraint(equalToConstant: 44)
        ])

        actionButton.addTarget(self, action: #selector(actionTapped), for: .touchUpInside)
    }

    @objc private func actionTapped() {
        onAction?()
    }
}

// MARK: - Convenience builders

extension StateView.Model {
    static func empty(title: String, message: String? = nil, actionTitle: String? = nil, onAction: (() -> Void)? = nil) -> StateView.Model {
        StateView.Model(
            kind: .empty,
            title: title,
            message: message,
            systemImageName: "tray",
            actionTitle: actionTitle,
            onAction: onAction
        )
    }

    static func error(title: String, message: String? = nil, actionTitle: String? = "Try again", onAction: (() -> Void)? = nil) -> StateView.Model {
        StateView.Model(
            kind: .error,
            title: title,
            message: message,
            systemImageName: "exclamationmark.triangle",
            actionTitle: actionTitle,
            onAction: onAction
        )
    }

    static func loading(title: String = "Loading…", message: String? = nil) -> StateView.Model {
        StateView.Model(
            kind: .loading,
            title: title,
            message: message,
            systemImageName: nil,
            actionTitle: nil,
            onAction: nil
        )
    }
}

// MARK: - Table helpers

extension UITableView {
    func setBackgroundState(_ model: StateView.Model?) {
        guard let model else {
            backgroundView = nil
            return
        }
        let v = StateView(model: model)
        v.layoutMargins = UIEdgeInsets(top: UIFactory.Theme.Spacing.xxl,
                                       left: UIFactory.Theme.Spacing.xxl,
                                       bottom: UIFactory.Theme.Spacing.xxl,
                                       right: UIFactory.Theme.Spacing.xxl)
        backgroundView = v
        // No separators on an empty background state.
        separatorStyle = .none
    }
}


