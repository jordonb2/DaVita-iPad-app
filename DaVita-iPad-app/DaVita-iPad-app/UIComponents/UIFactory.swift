import UIKit

/// Shared UI builders to keep view controllers slim and consistent.
///
/// `UIFactory.Theme` is the central place for colors/fonts/spacing decisions.
enum UIFactory {

    // MARK: - Theme

    enum Theme {
        enum Spacing {
            static let xs: CGFloat = 4
            static let s: CGFloat = 8
            static let m: CGFloat = 12
            static let l: CGFloat = 16
            static let xl: CGFloat = 20
            static let xxl: CGFloat = 24
            static let xxxl: CGFloat = 32
            static let huge: CGFloat = 36
        }

        enum CornerRadius {
            static let s: CGFloat = 8
            static let m: CGFloat = 12
            static let l: CGFloat = 14
            static let fab: CGFloat = 24
            static let xl: CGFloat = 24
            static let xxl: CGFloat = 32
        }

        enum Color {
            // Brand-ish accent used throughout the app.
            static let accent: UIColor = .systemIndigo

            static let textPrimary: UIColor = .label
            static let textSecondary: UIColor = .secondaryLabel

            static let surface: UIColor = .systemBackground
            static let surfaceElevated: UIColor = .secondarySystemBackground
            static let separator: UIColor = .separator

            static var fabBackground: UIColor { surface.withAlphaComponent(0.9) }

            // Hero gradient
            static let heroGradientStart: UIColor = .systemPurple
            static let heroGradientEnd: UIColor = accent
        }

        enum Font {
            static func preferred(_ style: UIFont.TextStyle) -> UIFont {
                UIFont.preferredFont(forTextStyle: style)
            }
        }

        enum Metrics {
            static let formTextViewMinHeight: CGFloat = 80
            static let formBorderWidth: CGFloat = 1

            static let fabSize: CGFloat = 48
            static let fabShadowOpacity: Float = 0.12
            static let fabShadowRadius: CGFloat = 8
            static let fabShadowOffset: CGSize = CGSize(width: 0, height: 2)

            static let buttonVerticalPadding: CGFloat = 14
            static let buttonHorizontalPadding: CGFloat = 16
        }
    }

    // MARK: - Labels / Headers

    static func sectionHeader(text: String, textStyle: UIFont.TextStyle = .title2) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = Theme.Font.preferred(textStyle)
        label.numberOfLines = 0
        label.accessibilityTraits.insert(.header)
        return label
    }

    // MARK: - Rows / Lists

    static func keyValueRow(title: String, value: String) -> UIView {
        let container = UIStackView()
        container.axis = .horizontal
        container.alignment = .center
        container.distribution = .fill

        container.isAccessibilityElement = true
        container.accessibilityLabel = "\(title), \(value)"

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = Theme.Font.preferred(.body)
        titleLabel.isAccessibilityElement = false

        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = Theme.Font.preferred(.body)
        valueLabel.textAlignment = .right
        valueLabel.setContentHuggingPriority(.required, for: .horizontal)
        valueLabel.isAccessibilityElement = false

        container.addArrangedSubview(titleLabel)
        container.addArrangedSubview(valueLabel)
        return container
    }

    static func categoryList(_ counts: [String: Int], emptyText: String = "—") -> UIView {
        let container = UIStackView()
        container.axis = .vertical
        container.spacing = Theme.Spacing.s

        if counts.isEmpty {
            let emptyLabel = UILabel()
            emptyLabel.text = emptyText
            emptyLabel.textColor = Theme.Color.textSecondary
            emptyLabel.isAccessibilityElement = true
            emptyLabel.accessibilityLabel = "No data yet"
            container.addArrangedSubview(emptyLabel)
            return container
        }

        let sorted = counts.sorted { $0.value > $1.value }.prefix(5)
        for (category, count) in sorted {
            container.addArrangedSubview(
                keyValueRow(title: category.replacingOccurrences(of: "_", with: " ").capitalized, value: "\(count)")
            )
        }

        return container
    }

    // MARK: - Buttons

    static func roundedActionButton(
        title: String,
        textStyle: UIFont.TextStyle = .headline,
        backgroundColor: UIColor = Theme.Color.surfaceElevated,
        cornerRadius: CGFloat = Theme.CornerRadius.m,
        contentInsets: UIEdgeInsets = UIEdgeInsets(
            top: Theme.Metrics.buttonVerticalPadding,
            left: Theme.Metrics.buttonHorizontalPadding,
            bottom: Theme.Metrics.buttonVerticalPadding,
            right: Theme.Metrics.buttonHorizontalPadding
        )
    ) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = Theme.Font.preferred(textStyle)
        button.contentHorizontalAlignment = .leading
        button.backgroundColor = backgroundColor
        button.layer.cornerRadius = cornerRadius
        button.contentEdgeInsets = contentInsets
        return button
    }

    // MARK: - Check-in specific sections

    static func textEntrySection(title: String?, textView: UITextView, placeholder: String) -> UIView {
        let container = UIStackView()
        container.axis = .vertical
        container.spacing = Theme.Spacing.s

        if let title {
            let titleLabel = UILabel()
            titleLabel.text = title
            titleLabel.font = Theme.Font.preferred(.headline)
            titleLabel.accessibilityTraits.insert(.header)
            container.addArrangedSubview(titleLabel)
            textView.accessibilityLabel = title
        }

        let placeholderLabel = UILabel()
        placeholderLabel.text = placeholder
        placeholderLabel.font = Theme.Font.preferred(.subheadline)
        placeholderLabel.textColor = Theme.Color.textSecondary
        placeholderLabel.isAccessibilityElement = false

        container.addArrangedSubview(placeholderLabel)
        container.addArrangedSubview(textView)
        return container
    }

    static func styleTextViewForForm(_ textView: UITextView) {
        textView.font = Theme.Font.preferred(.body)
        textView.layer.borderWidth = Theme.Metrics.formBorderWidth
        textView.layer.borderColor = Theme.Color.separator.cgColor
        textView.layer.cornerRadius = Theme.CornerRadius.s
        textView.isScrollEnabled = false
        textView.heightAnchor.constraint(greaterThanOrEqualToConstant: Theme.Metrics.formTextViewMinHeight).isActive = true
        textView.isAccessibilityElement = true
    }
}
