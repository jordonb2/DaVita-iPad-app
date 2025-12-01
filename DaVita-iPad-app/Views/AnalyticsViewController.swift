import UIKit

final class AnalyticsViewController: ScrolledStackViewController {

    var onLogoutConfirmed: (() -> Void)?

    private let adminSession: AdminSessioning
    private let summaryProvider: CheckInAnalyticsSummaryProviding
    private let exportService: ExportServicing
    private let historyViewControllerFactory: () -> CheckInHistoryViewController

    init(adminSession: AdminSessioning,
         summaryProvider: CheckInAnalyticsSummaryProviding,
         exportService: ExportServicing,
         historyViewControllerFactory: @escaping () -> CheckInHistoryViewController) {
        self.adminSession = adminSession
        self.summaryProvider = summaryProvider
        self.exportService = exportService
        self.historyViewControllerFactory = historyViewControllerFactory
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Analytics"
        view.backgroundColor = .systemBackground

        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Back", style: .plain, target: self, action: #selector(backTapped))

        isModalInPresentation = true
        presentationController?.delegate = self

        loadSummaryAndRender()

        NotificationCenter.default.addObserver(self, selector: #selector(adminDidAutoLogout), name: .adminSessionDidAutoLogout, object: nil)
    }

    private func loadSummaryAndRender() {
        let summary: CheckInAnalyticsSummaryProvider.Summary
        do {
            summary = try summaryProvider.makeSummary(since: nil)
        } catch {
            AppLog.analytics.error("Failed to load analytics summary: \(error, privacy: .public)")
            showToast(message: "Couldn't load analytics. Please try again.")
            summary = .empty
        }

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
        let orderedSteps: [CheckInAnalyticsStep] = [.pain, .energy, .mood, .symptoms, .concerns, .teamNote]
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

        contentStackView.addArrangedSubview(UIFactory.sectionHeader(text: "Export"))

        let exportCSV = UIFactory.roundedActionButton(title: "Export CSV")
        exportCSV.addTarget(self, action: #selector(exportCSVTapped(_:)), for: .touchUpInside)
        exportCSV.isAccessibilityElement = true
        exportCSV.accessibilityLabel = "Export CSV"
        exportCSV.accessibilityHint = "Exports check-in history to a CSV file on this device."
        contentStackView.addArrangedSubview(exportCSV)

        let exportPDF = UIFactory.roundedActionButton(title: "Export PDF")
        exportPDF.addTarget(self, action: #selector(exportPDFTapped(_:)), for: .touchUpInside)
        exportPDF.isAccessibilityElement = true
        exportPDF.accessibilityLabel = "Export PDF"
        exportPDF.accessibilityHint = "Exports check-in history to a PDF file on this device."
        contentStackView.addArrangedSubview(exportPDF)
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
        let vc = historyViewControllerFactory()
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc private func backTapped() {
        presentLogoutConfirmation()
    }



    @objc private func exportCSVTapped(_ sender: UIButton) {
        export(format: .csv, sourceView: sender)
    }

    @objc private func exportPDFTapped(_ sender: UIButton) {
        export(format: .pdf, sourceView: sender)
    }

    private enum ExportFormat {
        case csv
        case pdf
    }

    private func export(format: ExportFormat, sourceView: UIView) {
        guard adminSession.isLoggedIn else {
            let alert = AlertFactory.okAlert(title: "Admin required", message: "Please log in as admin to export.")
            present(alert, animated: true)
            return
        }

        do {
            let url: URL
            switch format {
            case .csv:
                url = try exportService.exportCheckInsCSV(filter: CheckInHistoryFilter())
            case .pdf:
                url = try exportService.exportCheckInsPDF(filter: CheckInHistoryFilter())
            }

            let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            if let popover = activity.popoverPresentationController {
                popover.sourceView = sourceView
                popover.sourceRect = sourceView.bounds
            }
            present(activity, animated: true)
        } catch {
            let alert = AlertFactory.okAlert(title: "Export failed", message: "Could not generate the export file.")
            present(alert, animated: true)
        }
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

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func adminDidAutoLogout() {
        // Auto-dismiss analytics when the admin session expires.
        onLogoutConfirmed?()
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
