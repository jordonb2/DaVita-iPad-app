//
//  LandingHeroHeaderView.swift
//  DaVita-iPad-app
//
//  Created by GPT-5.1 Codex on 11/19/25.
//

import UIKit

/// A lightweight hero view that gives the landing experience a more premium feel
/// without relying on storyboard elements. It is fully self-contained so it can
/// be dropped into any table/scroll view header.
final class LandingHeroHeaderView: UIView {

    struct Metric {
        let title: String
        let value: String
        let footnote: String
    }

    struct Model {
        let greeting: String
        let headline: String
        let subtitle: String
        let primaryButtonTitle: String
        let secondaryButtonTitle: String
        let metrics: [Metric]
    }

    // MARK: - Callbacks

    var onPrimaryTap: (() -> Void)?
    var onSecondaryTap: (() -> Void)?

    // MARK: - Layers & Views

    private let gradientLayer: CAGradientLayer = {
        let layer = CAGradientLayer()
        layer.colors = [
            UIFactory.Theme.Color.heroGradientStart.withAlphaComponent(0.9).cgColor,
            UIFactory.Theme.Color.heroGradientEnd.withAlphaComponent(0.9).cgColor
        ]
        layer.startPoint = CGPoint(x: 0, y: 0)
        layer.endPoint = CGPoint(x: 1, y: 1)
        return layer
    }()

    private let blurView: UIVisualEffectView = {
        let blur = UIBlurEffect(style: .systemMaterialLight)
        let view = UIVisualEffectView(effect: blur)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = UIFactory.Theme.CornerRadius.xl
        view.clipsToBounds = true
        return view
    }()

    private let contentStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = UIFactory.Theme.Spacing.l
        return stack
    }()

    private let badgeLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = LandingHeroHeaderView.scaledFont(size: 12, weight: .semibold, textStyle: .caption2)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .white
        label.backgroundColor = UIColor.white.withAlphaComponent(0.18)
        label.textAlignment = .center
        label.layer.cornerRadius = UIFactory.Theme.CornerRadius.m
        label.clipsToBounds = true
        label.text = "CLIENT SUCCESS"
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        label.isAccessibilityElement = false
        return label
    }()

    private let greetingLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = LandingHeroHeaderView.scaledFont(size: 16, weight: .medium, textStyle: .subheadline)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = UIColor.white.withAlphaComponent(0.9)
        label.text = "Welcome back"
        return label
    }()

    private let headlineLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = LandingHeroHeaderView.scaledFont(size: 34, weight: .bold, textStyle: .largeTitle)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .white
        label.numberOfLines = 0
        label.accessibilityTraits.insert(.header)
        label.text = "Care Hub"
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = LandingHeroHeaderView.scaledFont(size: 17, weight: .regular, textStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = UIColor.white.withAlphaComponent(0.9)
        label.numberOfLines = 0
        label.text = "Keep every client conversation warm and every record current."
        return label
    }()

    private let ctaStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.spacing = UIFactory.Theme.Spacing.m
        stack.distribution = .fillEqually
        return stack
    }()

    private let primaryButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Add Client", for: .normal)
        button.backgroundColor = UIColor.white
        button.setTitleColor(UIFactory.Theme.Color.accent, for: .normal)
        if let titleLabel = button.titleLabel {
            titleLabel.font = LandingHeroHeaderView.scaledFont(size: 17, weight: .semibold, textStyle: .headline)
            titleLabel.adjustsFontForContentSizeCategory = true
        }
        button.layer.cornerRadius = UIFactory.Theme.CornerRadius.l
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 54).isActive = true
        button.contentEdgeInsets = UIEdgeInsets(top: 14, left: 16, bottom: 14, right: 16)
        return button
    }()

    private let secondaryButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("View Records", for: .normal)
        button.setTitleColor(.white, for: .normal)
        if let titleLabel = button.titleLabel {
            titleLabel.font = LandingHeroHeaderView.scaledFont(size: 17, weight: .medium, textStyle: .headline)
            titleLabel.adjustsFontForContentSizeCategory = true
        }
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.white.withAlphaComponent(0.5).cgColor
        button.layer.cornerRadius = UIFactory.Theme.CornerRadius.l
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 54).isActive = true
        button.contentEdgeInsets = UIEdgeInsets(top: 14, left: 16, bottom: 14, right: 16)
        return button
    }()

    private let metricsStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.spacing = UIFactory.Theme.Spacing.m
        stack.distribution = .fillEqually
        return stack
    }()

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerRadius = UIFactory.Theme.CornerRadius.xxl
        clipsToBounds = true
        layer.insertSublayer(gradientLayer, at: 0)

        addSubview(contentStack)
        contentStack.addArrangedSubview(badgeLabel)
        contentStack.setCustomSpacing(4, after: badgeLabel)
        contentStack.addArrangedSubview(greetingLabel)
        contentStack.addArrangedSubview(headlineLabel)
        contentStack.addArrangedSubview(subtitleLabel)
        contentStack.addArrangedSubview(ctaStack)
        contentStack.addArrangedSubview(blurView)
        blurView.contentView.addSubview(metricsStack)

        ctaStack.addArrangedSubview(primaryButton)
        ctaStack.addArrangedSubview(secondaryButton)

        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: topAnchor, constant: 24),
            contentStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            contentStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            contentStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -24),

            metricsStack.topAnchor.constraint(equalTo: blurView.contentView.topAnchor, constant: 20),
            metricsStack.leadingAnchor.constraint(equalTo: blurView.contentView.leadingAnchor, constant: 20),
            metricsStack.trailingAnchor.constraint(equalTo: blurView.contentView.trailingAnchor, constant: -20),
            metricsStack.bottomAnchor.constraint(equalTo: blurView.contentView.bottomAnchor, constant: -20)
        ])

        primaryButton.addTarget(self, action: #selector(primaryTapped), for: .touchUpInside)
        secondaryButton.addTarget(self, action: #selector(secondaryTapped), for: .touchUpInside)

        // Seed placeholder metrics
        apply(defaultModel())
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }

    // MARK: - Configuration

    func apply(_ model: Model) {
        greetingLabel.text = model.greeting.uppercased()
        headlineLabel.text = model.headline
        subtitleLabel.text = model.subtitle
        primaryButton.setTitle(model.primaryButtonTitle, for: .normal)
        secondaryButton.setTitle(model.secondaryButtonTitle, for: .normal)
        setMetrics(model.metrics)

        primaryButton.accessibilityLabel = model.primaryButtonTitle
        primaryButton.accessibilityHint = "Opens the add client screen."
        secondaryButton.accessibilityLabel = model.secondaryButtonTitle
        secondaryButton.accessibilityHint = "Jumps to your latest record."

        var orderedElements: [Any] = [greetingLabel, headlineLabel, subtitleLabel, primaryButton, secondaryButton]
        orderedElements.append(contentsOf: metricsStack.arrangedSubviews)
        accessibilityElements = orderedElements
    }

    private func setMetrics(_ metrics: [Metric]) {
        metricsStack.arrangedSubviews.forEach { view in
            metricsStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        metrics.forEach { metric in
            let metricView = MetricCardView()
            metricView.configure(with: metric)
            metricsStack.addArrangedSubview(metricView)
        }
    }

    private func defaultModel() -> Model {
        let metric = Metric(title: "Active Clients", value: "—", footnote: "Add your first record")
        return Model(
            greeting: "Welcome",
            headline: "DaVita Care Hub",
            subtitle: "Launch every visit prepared. Keep client journeys personal.",
            primaryButtonTitle: "Add Client",
            secondaryButtonTitle: "View Records",
            metrics: [metric]
        )
    }

    // MARK: - Actions

    @objc private func primaryTapped() {
        onPrimaryTap?()
    }

    @objc private func secondaryTapped() {
        onSecondaryTap?()
    }
}

// MARK: - Metric Card

private final class MetricCardView: UIView {
    private let titleLabel = UILabel()
    private let valueLabel = UILabel()
    private let footnoteLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerRadius = 18
        layer.borderWidth = 1
        layer.borderColor = UIColor.white.withAlphaComponent(0.25).cgColor
        backgroundColor = UIColor.white.withAlphaComponent(0.08)

        isAccessibilityElement = true
        accessibilityTraits.insert(.staticText)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = LandingHeroHeaderView.scaledFont(size: 13, weight: .semibold, textStyle: .caption1)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textColor = UIColor.white.withAlphaComponent(0.85)
        titleLabel.isAccessibilityElement = false

        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.font = LandingHeroHeaderView.scaledFont(size: 28, weight: .bold, textStyle: .title2)
        valueLabel.adjustsFontForContentSizeCategory = true
        valueLabel.textColor = .white
        valueLabel.isAccessibilityElement = false

        footnoteLabel.translatesAutoresizingMaskIntoConstraints = false
        footnoteLabel.font = LandingHeroHeaderView.scaledFont(size: 13, weight: .regular, textStyle: .caption1)
        footnoteLabel.adjustsFontForContentSizeCategory = true
        footnoteLabel.textColor = UIColor.white.withAlphaComponent(0.8)
        footnoteLabel.numberOfLines = 2
        footnoteLabel.isAccessibilityElement = false

        let stack = UIStackView(arrangedSubviews: [titleLabel, valueLabel, footnoteLabel])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 6

        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16)
        ])
    }

    func configure(with metric: LandingHeroHeaderView.Metric) {
        titleLabel.text = metric.title.uppercased()
        valueLabel.text = metric.value
        footnoteLabel.text = metric.footnote

        let footnotePart = metric.footnote.isEmpty ? "" : ", \(metric.footnote)"
        accessibilityLabel = "\(metric.title), \(metric.value)\(footnotePart)"
    }
}

// MARK: - Dynamic Type helpers

private extension LandingHeroHeaderView {
    static func scaledFont(size: CGFloat, weight: UIFont.Weight, textStyle: UIFont.TextStyle) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        return UIFontMetrics(forTextStyle: textStyle).scaledFont(for: base)
    }
}
