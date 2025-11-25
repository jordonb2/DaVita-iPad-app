import UIKit

final class AnalyticsViewController: UIViewController {

    var onLogoutConfirmed: (() -> Void)?

    private let scrollView = UIScrollView()
    private let contentStackView = UIStackView()

    private let summaryProvider = CheckInAnalyticsSummaryProvider()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Analytics"
        view.backgroundColor = .systemBackground

        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Back", style: .plain, target: self, action: #selector(backTapped))

        isModalInPresentation = true
        presentationController?.delegate = self

        configureLayout()
        loadSummaryAndRender()
    }

    private func configureLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        contentStackView.axis = .vertical
        contentStackView.spacing = 16
        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStackView)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 24),
            contentStackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -24),
            contentStackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 24),
            contentStackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
            contentStackView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -48)
        ])
    }

    private func loadSummaryAndRender() {
        let summary = summaryProvider.makeSummary()

        contentStackView.addArrangedSubview(makeSectionHeader(text: "Engagement"))
        contentStackView.addArrangedSubview(makeKeyValueRow(title: "Completed", value: "\(summary.totalSubmitted)"))
        contentStackView.addArrangedSubview(makeKeyValueRow(title: "Skipped", value: "\(summary.totalSkipped)"))
        contentStackView.addArrangedSubview(makeKeyValueRow(title: "Dismissed", value: "\(summary.totalDismissed)"))
        contentStackView.addArrangedSubview(makeKeyValueRow(title: "Completion Rate", value: percentText(summary.completionRate)))
        contentStackView.addArrangedSubview(makeKeyValueRow(title: "Skip Rate", value: percentText(summary.skipRate)))
        contentStackView.addArrangedSubview(makeKeyValueRow(title: "Avg Completion Time", value: secondsText(summary.averageCompletionSeconds)))
        contentStackView.addArrangedSubview(makeKeyValueRow(title: "Avg Skip Time", value: secondsText(summary.averageSkipSeconds)))

        contentStackView.addArrangedSubview(makeSectionHeader(text: "Responses"))
        contentStackView.addArrangedSubview(makeKeyValueRow(title: "High Pain Rate", value: percentText(summary.highPainRate)))
        contentStackView.addArrangedSubview(makeKeyValueRow(title: "Low Energy Rate", value: percentText(summary.lowEnergyRate)))

        contentStackView.addArrangedSubview(makeSectionHeader(text: "Step Drop-Off Signals"))
        let orderedSteps: [CheckInAnalyticsLogger.Step] = [.pain, .energy, .mood, .symptoms, .concerns, .teamNote]
        for step in orderedSteps {
            let count = summary.stepFirstInteractionCounts[step] ?? 0
            contentStackView.addArrangedSubview(makeKeyValueRow(title: step.rawValue.capitalized, value: "\(count)"))
        }

        contentStackView.addArrangedSubview(makeSectionHeader(text: "Top Symptoms"))
        contentStackView.addArrangedSubview(makeCategoryList(summary.symptomCategoryCounts))

        contentStackView.addArrangedSubview(makeSectionHeader(text: "Top Concerns"))
        contentStackView.addArrangedSubview(makeCategoryList(summary.concernCategoryCounts))

        contentStackView.addArrangedSubview(makeSectionHeader(text: "By Daypart"))
        for daypart in [Daypart.morning, Daypart.afternoon, Daypart.evening, Daypart.night] {
            let count = summary.submissionsByDaypart[daypart] ?? 0
            contentStackView.addArrangedSubview(makeKeyValueRow(title: daypart.rawValue.capitalized, value: "\(count)"))
        }

        contentStackView.addArrangedSubview(makeSectionHeader(text: "History"))
        contentStackView.addArrangedSubview(makeHistoryButton())
    }

    private func makeSectionHeader(text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = UIFont.preferredFont(forTextStyle: .title2)
        label.numberOfLines = 0
        label.accessibilityTraits.insert(.header)
        return label
    }

    private func makeKeyValueRow(title: String, value: String) -> UIView {
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

    private func makeCategoryList(_ counts: [String: Int]) -> UIView {
        let container = UIStackView()
        container.axis = .vertical
        container.spacing = 8

        if counts.isEmpty {
            let emptyLabel = UILabel()
            emptyLabel.text = "—"
            emptyLabel.textColor = .secondaryLabel
            emptyLabel.isAccessibilityElement = true
            emptyLabel.accessibilityLabel = "No data yet"
            container.addArrangedSubview(emptyLabel)
            return container
        }

        let sorted = counts.sorted { $0.value > $1.value }.prefix(5)
        for (category, count) in sorted {
            container.addArrangedSubview(makeKeyValueRow(title: category.replacingOccurrences(of: "_", with: " ").capitalized, value: "\(count)"))
        }

        return container
    }

    private func percentText(_ value: Double) -> String {
        let percent = Int((value * 100).rounded())
        return "\(percent)%"
    }

    private func secondsText(_ value: Double) -> String {
        let roundedSeconds = Int(value.rounded())
        return "\(roundedSeconds)s"
    }

    private func makeHistoryButton() -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle("View Visit History", for: .normal)
        button.titleLabel?.font = UIFont.preferredFont(forTextStyle: .headline)
        button.contentHorizontalAlignment = .leading
        button.backgroundColor = UIColor.secondarySystemBackground
        button.layer.cornerRadius = 12
        button.contentEdgeInsets = UIEdgeInsets(top: 14, left: 16, bottom: 14, right: 16)
        button.addTarget(self, action: #selector(historyTapped), for: .touchUpInside)
        button.isAccessibilityElement = true
        button.accessibilityLabel = "View visit history"
        button.accessibilityHint = "Shows multi-visit check-in records by person."
        return button
    }

    @objc private func historyTapped() {
        let vc = CheckInHistoryViewController()
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc private func backTapped() {
        presentLogoutConfirmation()
    }

    private func presentLogoutConfirmation() {
        let alert = UIAlertController(title: "Log out?", message: "Are you sure you want to log-out?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "No", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Yes", style: .destructive) { [weak self] _ in
            self?.onLogoutConfirmed?()
        })
        present(alert, animated: true)
    }
}

extension AnalyticsViewController: UIAdaptivePresentationControllerDelegate {
    func presentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool {
        return false
    }

    func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) {
        presentLogoutConfirmation()
    }
}
