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

            // MARK: - Accessibility-aware "on hero" colors

            /// Primary text drawn on top of the hero gradient.
            static var heroTextPrimary: UIColor {
                UIColor { tc in
                    // Always keep primary hero text fully opaque for contrast.
                    return .white
                }
            }

            /// Secondary text on top of the hero gradient (can be slightly subdued unless in high contrast).
            static var heroTextSecondary: UIColor {
                UIColor { tc in
                    if tc.accessibilityContrast == .high || UIAccessibility.isDarkerSystemColorsEnabled {
                        return .white
                    }
                    return UIColor.white.withAlphaComponent(0.9)
                }
            }

            /// Background for the hero badge pill (avoid white-on-white low contrast).
            static var heroBadgeBackground: UIColor {
                UIColor { tc in
                    let alpha: CGFloat = (tc.accessibilityContrast == .high || UIAccessibility.isDarkerSystemColorsEnabled) ? 0.38 : 0.26
                    return UIColor.black.withAlphaComponent(alpha)
                }
            }

            /// Background for hero metric cards.
            static var heroCardBackground: UIColor {
                UIColor { tc in
                    let alpha: CGFloat = (tc.accessibilityContrast == .high || UIAccessibility.isDarkerSystemColorsEnabled) ? 0.22 : 0.14
                    return UIColor.black.withAlphaComponent(alpha)
                }
            }

            /// Border color for hero metric cards.
            static var heroCardBorder: UIColor {
                UIColor { tc in
                    let alpha: CGFloat = (tc.accessibilityContrast == .high || UIAccessibility.isDarkerSystemColorsEnabled) ? 0.45 : 0.32
                    return UIColor.white.withAlphaComponent(alpha)
                }
            }

            /// Border color for secondary hero CTA.
            static var heroSecondaryButtonBorder: UIColor {
                UIColor { tc in
                    let alpha: CGFloat = (tc.accessibilityContrast == .high || UIAccessibility.isDarkerSystemColorsEnabled) ? 0.8 : 0.55
                    return UIColor.white.withAlphaComponent(alpha)
                }
            }

            /// Toast background (more opaque in high contrast).
            static var toastBackground: UIColor {
                UIColor { tc in
                    let alpha: CGFloat = (tc.accessibilityContrast == .high || UIAccessibility.isDarkerSystemColorsEnabled) ? 0.92 : 0.80
                    return UIColor.black.withAlphaComponent(alpha)
                }
            }
        }

        // MARK: - Typography

        enum TypographyToken {
            case heroTitle
            case sectionHeader
            case headline
            case body
            case subheadline
            case footnote
            case button
            case monospaceCaption
        }

        enum Typography {
            static func font(_ token: TypographyToken) -> UIFont {
                switch token {
                case .heroTitle:
                    return UIFont.preferredFont(forTextStyle: .largeTitle)
                case .sectionHeader:
                    return UIFont.preferredFont(forTextStyle: .title2)
                case .headline:
                    return UIFont.preferredFont(forTextStyle: .headline)
                case .body:
                    return UIFont.preferredFont(forTextStyle: .body)
                case .subheadline:
                    return UIFont.preferredFont(forTextStyle: .subheadline)
                case .footnote:
                    return UIFont.preferredFont(forTextStyle: .footnote)
                case .button:
                    return UIFont.preferredFont(forTextStyle: .headline)
                case .monospaceCaption:
                    let base = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
                    return UIFontMetrics(forTextStyle: .caption2).scaledFont(for: base)
                }
            }

            static func apply(_ token: TypographyToken, to label: UILabel) {
                label.font = font(token)
                label.adjustsFontForContentSizeCategory = true
            }
        }

        // MARK: - Line height

        enum LineHeightToken {
            case body
            case subheadline
            case footnote
            case title
        }

        enum LineHeight {
            /// Multiplier applied to the font's line height via `paragraphStyle.lineHeightMultiple`.
            static func multiple(_ token: LineHeightToken) -> CGFloat {
                switch token {
                case .body: return 1.15
                case .subheadline: return 1.15
                case .footnote: return 1.12
                case .title: return 1.05
                }
            }

            static func paragraphStyle(for token: LineHeightToken) -> NSMutableParagraphStyle {
                let p = NSMutableParagraphStyle()
                p.lineHeightMultiple = multiple(token)
                p.lineBreakMode = .byWordWrapping
                return p
            }
        }

        // MARK: - Motion

        enum Animation {
            enum Duration {
                static let xFast: TimeInterval = 0.12
                static let fast: TimeInterval = 0.20
                static let standard: TimeInterval = 0.25
                static let slow: TimeInterval = 0.35
            }

            enum Curve {
                static let standard: UIView.AnimationOptions = [.curveEaseInOut]
                static let enter: UIView.AnimationOptions = [.curveEaseOut]
                static let exit: UIView.AnimationOptions = [.curveEaseIn]
            }

            struct Spring {
                let duration: TimeInterval
                let dampingRatio: CGFloat
                let velocity: CGFloat

                static let standard = Spring(duration: Duration.standard, dampingRatio: 0.86, velocity: 0)
            }
        }

        // MARK: - Elevation / Shadow

        struct ShadowToken {
            let color: UIColor
            let opacity: Float
            let radius: CGFloat
            let offset: CGSize

            func apply(to layer: CALayer) {
                layer.shadowColor = color.cgColor
                layer.shadowOpacity = opacity
                layer.shadowRadius = radius
                layer.shadowOffset = offset
                layer.masksToBounds = false
            }
        }

        enum Shadow {
            static let none = ShadowToken(color: .clear, opacity: 0, radius: 0, offset: .zero)
            static let card = ShadowToken(color: .black, opacity: 0.08, radius: 10, offset: CGSize(width: 0, height: 2))
            static let fab = ShadowToken(color: .black, opacity: 0.12, radius: 8, offset: CGSize(width: 0, height: 2))
            static let overlay = ShadowToken(color: .black, opacity: 0.20, radius: 16, offset: CGSize(width: 0, height: 6))
        }

        // MARK: - Z-order

        enum ZIndex {
            static let background: CGFloat = 0
            static let content: CGFloat = 1
            static let floating: CGFloat = 100
            static let overlay: CGFloat = 200
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
            // Prefer `Theme.Shadow.fab` for new code.
            static let fabShadowOpacity: Float = Shadow.fab.opacity
            static let fabShadowRadius: CGFloat = Shadow.fab.radius
            static let fabShadowOffset: CGSize = Shadow.fab.offset

            static let buttonVerticalPadding: CGFloat = 14
            static let buttonHorizontalPadding: CGFloat = 16
        }
    }

    // MARK: - Labels / Headers

    static func sectionHeader(text: String, textStyle: UIFont.TextStyle = .title2) -> UILabel {
        let label = UILabel()
        label.text = text
        // Default: tokenized typography. If a caller passes a custom `textStyle`, honor it.
        if textStyle == .title2 {
            Theme.Typography.apply(.sectionHeader, to: label)
        } else {
            label.font = Theme.Font.preferred(textStyle)
            label.adjustsFontForContentSizeCategory = true
        }
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
        Theme.Typography.apply(.body, to: titleLabel)
        titleLabel.isAccessibilityElement = false

        let valueLabel = UILabel()
        valueLabel.text = value
        Theme.Typography.apply(.body, to: valueLabel)
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
            Theme.Typography.apply(.body, to: emptyLabel)
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

    // MARK: - Cards / Layout helpers

    static func cardContainer(backgroundColor: UIColor = Theme.Color.surfaceElevated,
                              cornerRadius: CGFloat = Theme.CornerRadius.m,
                              shadow: Theme.ShadowToken = Theme.Shadow.none) -> UIView {
        let v = UIView()
        v.backgroundColor = backgroundColor
        v.layer.cornerRadius = cornerRadius
        shadow.apply(to: v.layer)
        return v
    }

    static func verticalStack(spacing: CGFloat = Theme.Spacing.l) -> UIStackView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = spacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }

    static func pin(_ child: UIView, to container: UIView, insets: UIEdgeInsets) {
        child.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            child.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: insets.left),
            child.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -insets.right),
            child.topAnchor.constraint(equalTo: container.topAnchor, constant: insets.top),
            child.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -insets.bottom)
        ])
    }

    static func card(_ content: UIView, padding: CGFloat = Theme.Spacing.l) -> UIView {
        let container = cardContainer()
        container.addSubview(content)
        pin(content, to: container, insets: UIEdgeInsets(top: padding, left: padding, bottom: padding, right: padding))
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
        button.titleLabel?.adjustsFontForContentSizeCategory = true
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
            Theme.Typography.apply(.headline, to: titleLabel)
            titleLabel.accessibilityTraits.insert(.header)
            container.addArrangedSubview(titleLabel)
            textView.accessibilityLabel = title
        }

        let placeholderLabel = UILabel()
        placeholderLabel.text = placeholder
        Theme.Typography.apply(.subheadline, to: placeholderLabel)
        placeholderLabel.textColor = Theme.Color.textSecondary
        placeholderLabel.isAccessibilityElement = false

        container.addArrangedSubview(placeholderLabel)
        container.addArrangedSubview(textView)
        return container
    }

    static func styleTextViewForForm(_ textView: UITextView) {
        textView.font = Theme.Typography.font(.body)
        textView.adjustsFontForContentSizeCategory = true
        textView.layer.borderWidth = Theme.Metrics.formBorderWidth
        textView.layer.borderColor = Theme.Color.separator.cgColor
        textView.layer.cornerRadius = Theme.CornerRadius.s
        textView.isScrollEnabled = false
        textView.heightAnchor.constraint(greaterThanOrEqualToConstant: Theme.Metrics.formTextViewMinHeight).isActive = true
        textView.isAccessibilityElement = true
    }
}
