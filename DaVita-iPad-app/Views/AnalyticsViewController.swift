import UIKit
import Foundation

final class AnalyticsViewController: ScrolledStackViewController {

    var onLogoutConfirmed: (() -> Void)?

    private let adminSession: AdminSessioning
    private let summaryProvider: CheckInAnalyticsSummaryProviding
    private let exportService: ExportServicing
    private let historyViewControllerFactory: () -> CheckInHistoryViewController
    private let reminderManager: SmartReminderManaging
    private let summaryQueue = DispatchQueue(label: "com.davita.analytics.summary", qos: .userInitiated)

    enum ExportScope: Int, CaseIterable {
        case all
        case last30
        case last90

        var title: String {
            switch self {
            case .all: return "All"
            case .last30: return "30d"
            case .last90: return "90d"
            }
        }

        func filter(now: Date = Date()) -> CheckInHistoryFilter {
            switch self {
            case .all:
                return CheckInHistoryFilter()
            case .last30:
                let start = Calendar.current.date(byAdding: .day, value: -30, to: now)
                return CheckInHistoryFilter(startDate: start)
            case .last90:
                let start = Calendar.current.date(byAdding: .day, value: -90, to: now)
                return CheckInHistoryFilter(startDate: start)
            }
        }
    }

    private enum ViewState {
        case loading
        case empty
        case loaded(CheckInAnalyticsSummaryProvider.Summary)
        case error(AppError)
    }

    private var state: ViewState = .loading
    private var exportScope: ExportScope = .all
    private lazy var exportScopeControl: UISegmentedControl = {
        let control = UISegmentedControl(items: ExportScope.allCases.map { $0.title })
        control.selectedSegmentIndex = exportScope.rawValue
        control.addTarget(self, action: #selector(exportScopeChanged(_:)), for: .valueChanged)
        control.accessibilityLabel = "Export scope"
        control.accessibilityHint = "Choose how much history to include in exports."
        return control
    }()

    init(adminSession: AdminSessioning,
         summaryProvider: CheckInAnalyticsSummaryProviding,
         exportService: ExportServicing,
         historyViewControllerFactory: @escaping () -> CheckInHistoryViewController,
         reminderManager: SmartReminderManaging,
         defaultExportScope: ExportScope = .all) {
        self.adminSession = adminSession
        self.summaryProvider = summaryProvider
        self.exportService = exportService
        self.historyViewControllerFactory = historyViewControllerFactory
        self.reminderManager = reminderManager
        self.exportScope = defaultExportScope
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Analytics"
        view.backgroundColor = .systemBackground

        let logout = UIBarButtonItem(title: "Log out", style: .plain, target: self, action: #selector(backTapped))
        logout.accessibilityLabel = "Log out"
        logout.accessibilityHint = "Logs out of the admin session."
        navigationItem.leftBarButtonItem = logout

        let settings = UIBarButtonItem(title: "Settings", style: .plain, target: self, action: #selector(settingsTapped))
        settings.accessibilityLabel = "Admin settings"
        settings.accessibilityHint = "Configure privacy, exports, and auto-logout."
        navigationItem.rightBarButtonItem = settings

        isModalInPresentation = true
        presentationController?.delegate = self

        state = .loading
        render()
        reloadSummary()

        NotificationCenter.default.addObserver(self, selector: #selector(adminDidAutoLogout), name: .adminSessionDidAutoLogout, object: nil)
    }

    private func reloadSummary() {
        state = .loading
        DispatchQueue.main.async { [weak self] in
            self?.render()
        }

        summaryQueue.async { [weak self] in
            guard let self else { return }

            let result: Result<CheckInAnalyticsSummaryProvider.Summary, Error>
            do {
                let summary = try self.summaryProvider.makeSummary(since: nil)
                result = .success(summary)
            } catch {
                result = .failure(error)
            }

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                switch result {
                case .success(let summary):
                    let total = summary.totalPresented + summary.totalSubmitted + summary.totalSkipped + summary.totalDismissed
                    self.state = (total == 0) ? .empty : .loaded(summary)
                case .failure(let error):
                    AppLog.analytics.error("Failed to load analytics summary: \(error, privacy: .private)")
                    let appError = AppError(operation: .loadAnalytics, underlying: error)
                    self.present(appError: appError)
                    self.state = .error(appError)
                }
                self.render()
            }
        }
    }

    private func render() {
        resetContentStack()

        switch state {
        case .loading:
            contentStackView.addArrangedSubview(StateView(model: .loading(title: "Loading analytics…")))
            return

        case .empty:
            contentStackView.addArrangedSubview(
                StateView(model: .empty(
                    title: "No analytics yet",
                    message: "Complete a check-in to start seeing engagement and trends here.",
                    actionTitle: "Refresh",
                    onAction: { [weak self] in self?.reloadSummary() }
                ))
            )
            return

        case .error(let appError):
            let ui = appError.userFacing
            contentStackView.addArrangedSubview(
                StateView(model: .error(
                    title: ui.title,
                    message: ui.message,
                    actionTitle: ui.actionTitle ?? "Retry",
                    onAction: { [weak self] in self?.reloadSummary() }
                ))
            )
            return

        case .loaded:
            break
        }

        guard case .loaded(let summary) = state else { return }

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
        contentStackView.addArrangedSubview(exportScopeControl)

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

    @objc private func settingsTapped() {
        let settingsVC = AdminSettingsViewController(adminSession: adminSession, reminderManager: reminderManager)
        navigationController?.pushViewController(settingsVC, animated: true)
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
            present(appError: .authRequired)
            return
        }

        do {
            let url: URL
            let filter = exportScope.filter()
            switch format {
            case .csv:
                url = try exportService.exportCheckInsCSV(filter: filter)
            case .pdf:
                url = try exportService.exportCheckInsPDF(filter: filter)
            }

            let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            activity.completionWithItemsHandler = { _, _, _, _ in
                try? FileManager.default.removeItem(at: url)
            }
            if let popover = activity.popoverPresentationController {
                popover.sourceView = sourceView
                popover.sourceRect = sourceView.bounds
            }
            present(activity, animated: true)
        } catch {
            let op: AppError.Operation = (format == .csv) ? .exportCSV : .exportPDF
            present(appError: AppError(operation: op, underlying: error))
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

    @objc private func exportScopeChanged(_ sender: UISegmentedControl) {
        guard let scope = ExportScope(rawValue: sender.selectedSegmentIndex) else { return }
        exportScope = scope
        AdminSettings.defaultExportScopeRaw = sender.selectedSegmentIndex
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
