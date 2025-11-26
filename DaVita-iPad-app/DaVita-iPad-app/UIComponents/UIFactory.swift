import UIKit

/// Shared UI builders to keep view controllers slim and consistent.
enum UIFactory {

    // MARK: - Labels / Headers
    static func sectionHeader(text: String, textStyle: UIFont.TextStyle = .title2) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = UIFont.preferredFont(forTextStyle: textStyle)
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
        titleLabel.font = UIFont.preferredFont(forTextStyle: .body)
        titleLabel.isAccessibilityElement = false

        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = UIFont.preferredFont(forTextStyle: .body)
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
        container.spacing = 8

        if counts.isEmpty {
            let emptyLabel = UILabel()
            emptyLabel.text = emptyText
            emptyLabel.textColor = .secondaryLabel
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
    static func roundedActionButton(title: String,
                                    textStyle: UIFont.TextStyle = .headline,
                                    backgroundColor: UIColor = .secondarySystemBackground,
                                    cornerRadius: CGFloat = 12,
                                    contentInsets: UIEdgeInsets = UIEdgeInsets(top: 14, left: 16, bottom: 14, right: 16)) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont.preferredFont(forTextStyle: textStyle)
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
        container.spacing = 8

        if let title {
            let titleLabel = UILabel()
            titleLabel.text = title
            titleLabel.font = UIFont.preferredFont(forTextStyle: .headline)
            titleLabel.accessibilityTraits.insert(.header)
            container.addArrangedSubview(titleLabel)
            textView.accessibilityLabel = title
        }

        let placeholderLabel = UILabel()
        placeholderLabel.text = placeholder
        placeholderLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
        placeholderLabel.textColor = .secondaryLabel
        placeholderLabel.isAccessibilityElement = false

        container.addArrangedSubview(placeholderLabel)
        container.addArrangedSubview(textView)
        return container
    }

    static func styleTextViewForForm(_ textView: UITextView) {
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.layer.borderWidth = 1
        textView.layer.borderColor = UIColor.separator.cgColor
        textView.layer.cornerRadius = 8
        textView.isScrollEnabled = false
        textView.heightAnchor.constraint(greaterThanOrEqualToConstant: 80).isActive = true
        textView.isAccessibilityElement = true
    }
}
