import UIKit

final class AnalyticsViewController: ScrolledStackViewController {

    var onLogoutConfirmed: (() -> Void)?

    private let summaryProvider = CheckInAnalyticsSummaryProvider()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Analytics"
        view.backgroundColor = .systemBackground

        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Back", style: .plain, target: self, action: #selector(backTapped))

        isModalInPresentation = true
        presentationController?.delegate = self

        loadSummaryAndRender()
    }

    private func loadSummaryAndRender() {
        let summary = summaryProvider.makeSummary()

        contentStackView.addArrangedSubview(UIFactory.sectionHeader(text: "Engagement"))
        contentStackView.addArrangedSubview(UIFactory.keyValueRow(title: "Completed", value: "\(summary.totalSubmitted)"))
        contentStackView.addArrangedSubview(UIFactory.keyValueRow(title: "Skipped", value: "\(summary.totalSkipped)"))
        contentStackView.addArrangedSubview(UIFactory.keyValueRow(title: "Dismissed", value: "\(summary.totalDismissed)"))
        contentStackView.addArrangedSubview(UIFactory.keyValueRow(title: "Completion Rate", value: percentText(summary.completionRate)))
        contentStackView.addArrangedSubview(UIFactory.keyValueRow(title: "Skip Rate", value: percentText(summary.skipRate)))
        contentStackView.addArrangedSubview(UIFactory.keyValueRow(title: "Avg Completion Time", value: secondsText(summary.averageCompletionSeconds)))
        contentStackView.addArrangedSubview(UIFactory.keyValueRow(title: "Avg Skip Time", value: secondsText(summary.averageSkipSeconds)))

        contentStackView.addArrangedSubview(UIFactory.sectionHeader(text: "Responses"))
        contentStackView.addArrangedSubview(UIFactory.keyValueRow(title: "High Pain Rate", value: percentText(summary.highPainRate)))
        contentStackView.addArrangedSubview(UIFactory.keyValueRow(title: "Low Energy Rate", value: percentText(summary.lowEnergyRate)))

        contentStackView.addArrangedSubview(UIFactory.sectionHeader(text: "Step Drop-Off Signals"))
        let orderedSteps: [CheckInAnalyticsLogger.Step] = [.pain, .energy, .mood, .symptoms, .concerns, .teamNote]
        for step in orderedSteps {
            let count = summary.stepFirstInteractionCounts[step] ?? 0
            contentStackView.addArrangedSubview(UIFactory.keyValueRow(title: step.rawValue.capitalized, value: "\(count)"))
        }

        contentStackView.addArrangedSubview(UIFactory.sectionHeader(text: "Top Symptoms"))
        contentStackView.addArrangedSubview(UIFactory.categoryList(summary.symptomCategoryCounts))

        contentStackView.addArrangedSubview(UIFactory.sectionHeader(text: "Top Concerns"))
        contentStackView.addArrangedSubview(UIFactory.categoryList(summary.concernCategoryCounts))

        contentStackView.addArrangedSubview(UIFactory.sectionHeader(text: "By Daypart"))
        for daypart in [Daypart.morning, Daypart.afternoon, Daypart.evening, Daypart.night] {
            let count = summary.submissionsByDaypart[daypart] ?? 0
            contentStackView.addArrangedSubview(UIFactory.keyValueRow(title: daypart.rawValue.capitalized, value: "\(count)"))
        }

        contentStackView.addArrangedSubview(UIFactory.sectionHeader(text: "History"))
        let historyButton = UIFactory.roundedActionButton(title: "View Visit History")
        historyButton.addTarget(self, action: #selector(historyTapped), for: .touchUpInside)
        historyButton.isAccessibilityElement = true
        historyButton.accessibilityLabel = "View visit history"
        historyButton.accessibilityHint = "Shows multi-visit check-in records by person."
        contentStackView.addArrangedSubview(historyButton)
    }

    private func percentText(_ value: Double) -> String {
        let percent = Int((value * 100).rounded())
        return "\(percent)%"
    }

    private func secondsText(_ value: Double) -> String {
        let roundedSeconds = Int(value.rounded())
        return "\(roundedSeconds)s"
    }

    @objc private func historyTapped() {
        let vc = CheckInHistoryViewController()
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc private func backTapped() {
        presentLogoutConfirmation()
    }

    private func presentLogoutConfirmation() {
        let alert = AlertFactory.confirmAlert(
            title: "Log out?",
            message: "Are you sure you want to log-out?",
            confirmTitle: "Yes",
            cancelTitle: "No",
            isDestructive: true
        ) { [weak self] in
            self?.onLogoutConfirmed?()
        }
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
