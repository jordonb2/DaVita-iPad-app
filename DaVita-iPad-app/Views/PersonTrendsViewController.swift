import UIKit
import MessageUI

/// Per-person trends computed from check-in history.
final class PersonTrendsViewController: ScrolledStackViewController {

    private let person: Person
    private let trendsProvider: CheckInTrendsProviding

    private let windowDays: Int

    private enum ViewState {
        case loading
        case empty
        case loaded(CheckInTrendsProvider.PersonTrends)
        case error(AppError)
    }

    private var state: ViewState = .loading
    private let sharingStore: TrendSharingPreferencesStoring
    private let pdfGenerator: TrendSummaryPDFGenerating
    private var sharingPreferences: TrendSharingPreferences
    private var currentTrends: CheckInTrendsProvider.PersonTrends?
    private var pendingShareURL: URL?
    private var hasPromptedThisSession = false

    private lazy var statusDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        return df
    }()

    private lazy var shareToggle: UISwitch = {
        let toggle = UISwitch()
        toggle.addTarget(self, action: #selector(sharingToggleChanged(_:)), for: .valueChanged)
        toggle.accessibilityLabel = "Enable monthly summary"
        return toggle
    }()

    private lazy var recipientsField: UITextField = {
        let field = UITextField()
        field.placeholder = "Emails (comma separated)"
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.keyboardType = .emailAddress
        field.borderStyle = .roundedRect
        field.delegate = self
        return field
    }()

    private lazy var shareStatusLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.textColor = UIFactory.Theme.Color.textSecondary
        label.font = UIFactory.Theme.Font.preferred(.footnote)
        label.adjustsFontForContentSizeCategory = true
        return label
    }()

    private lazy var shareNowButton: UIButton = {
        let button = UIFactory.roundedActionButton(title: "Send summary now")
        button.addTarget(self, action: #selector(shareNowTapped(_:)), for: .touchUpInside)
        button.accessibilityLabel = "Send monthly summary now"
        return button
    }()

    init(person: Person,
         windowDays: Int = 30,
         trendsProvider: CheckInTrendsProviding,
         sharingStore: TrendSharingPreferencesStoring = TrendSharingPreferencesStore(),
         pdfGenerator: TrendSummaryPDFGenerating = TrendSummaryPDFGenerator()) {
        self.person = person
        self.windowDays = windowDays
        self.trendsProvider = trendsProvider
        self.sharingStore = sharingStore
        self.pdfGenerator = pdfGenerator
        if let id = person.id {
            self.sharingPreferences = sharingStore.load(personID: id)
        } else {
            self.sharingPreferences = TrendSharingPreferences()
        }
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Trends"
        view.backgroundColor = UIFactory.Theme.Color.surface
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Share", style: .plain, target: self, action: #selector(shareNowFromNav))

        shareToggle.isOn = sharingPreferences.isEnabled
        recipientsField.text = sharingPreferences.recipients.joined(separator: ", ")
        updateSharingUI()

        state = .loading
        render()
        reloadTrends()
    }

    private func reloadTrends() {
        let trends: CheckInTrendsProvider.PersonTrends
        do {
            trends = try trendsProvider.computeTrends(for: person, windowDays: windowDays, maxRecords: 250)
        } catch {
            AppLog.persistence.error("Failed to compute trends: \(error, privacy: .private)")
            let appError = AppError(operation: .loadTrends, underlying: error)
            present(appError: appError)
            state = .error(appError)
            currentTrends = nil
            render()
            return
        }

        currentTrends = trends
        state = (trends.totalRecordsInWindow == 0) ? .empty : .loaded(trends)
        render()
        maybePromptMonthlyShare()
    }

    private func render() {
        resetContentStack()

        switch state {
        case .loading:
            contentStackView.addArrangedSubview(StateView(model: .loading(title: "Loading trends…")))
            return

        case .empty:
            contentStackView.addArrangedSubview(
                StateView(model: .empty(
                    title: "No trends yet",
                    message: "This person doesn't have check-ins in the last \(windowDays) days.",
                    actionTitle: "Refresh",
                    onAction: { [weak self] in self?.reloadTrends() }
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
                    onAction: { [weak self] in self?.reloadTrends() }
                ))
            )
            return

        case .loaded:
            break
        }

        guard case .loaded(let trends) = state else { return }

        contentStackView.addArrangedSubview(UIFactory.sectionHeader(text: "Pain (last \(windowDays) days)", textStyle: .title2))
        contentStackView.addArrangedSubview(painCard(series: trends.painSeries))

        contentStackView.addArrangedSubview(UIFactory.sectionHeader(text: "Energy distribution", textStyle: .title2))
        contentStackView.addArrangedSubview(distributionCard(title: "Energy", counts: trends.energyDistribution, allBuckets: EnergyBucket.allCases))

        contentStackView.addArrangedSubview(UIFactory.sectionHeader(text: "Mood distribution", textStyle: .title2))
        contentStackView.addArrangedSubview(distributionCard(title: "Mood", counts: trends.moodDistribution, allBuckets: MoodBucket.allCases))

        contentStackView.addArrangedSubview(UIFactory.sectionHeader(text: "Symptoms over time", textStyle: .title2))
        contentStackView.addArrangedSubview(symptomsCard(trends: trends))

        contentStackView.addArrangedSubview(UIFactory.sectionHeader(text: "Share monthly summary", textStyle: .title2))
        contentStackView.addArrangedSubview(sharingCard(trends: trends))
    }

    private func painCard(series: [CheckInTrendsProvider.Point]) -> UIView {
        let stack = UIFactory.verticalStack()

        let values = series.map { CGFloat($0.value) }
        let spark = SparklineView(
            values: values,
            strokeColor: UIFactory.Theme.Color.accent,
            accessibilityLabelText: "Pain trend",
            accessibilityValueText: painTrendAccessibility(series: series),
            accessibilityHintText: "Chart of pain levels over time."
        )
        spark.heightAnchor.constraint(equalToConstant: 56).isActive = true

        let summary = UILabel()
        summary.numberOfLines = 0
        summary.font = UIFactory.Theme.Font.preferred(.subheadline)
        summary.adjustsFontForContentSizeCategory = true
        summary.textColor = UIFactory.Theme.Color.textSecondary

        if let last = series.last {
            let v = Int(last.value.rounded())
            summary.text = "Latest: \(v)/10 • \(series.count) points"
        } else {
            summary.text = "No check-ins in this window"
        }

        stack.addArrangedSubview(spark)
        stack.addArrangedSubview(summary)

        return UIFactory.card(stack)
    }

    private func distributionCard<T: CaseIterable & Hashable>(
        title: String,
        counts: [T: Int],
        allBuckets: [T]
    ) -> UIView {
        let stack = UIFactory.verticalStack()

        let total = counts.values.reduce(0, +)
        for bucket in allBuckets {
            let count = counts[bucket, default: 0]
            let row = DistributionRow(
                title: bucketTitle(bucket),
                valueText: total == 0 ? "—" : "\(count)",
                fraction: total == 0 ? 0 : CGFloat(count) / CGFloat(total)
            )
            stack.addArrangedSubview(row)
        }

        return UIFactory.card(stack)
    }

    private func symptomsCard(trends: CheckInTrendsProvider.PersonTrends) -> UIView {
        let stack = UIFactory.verticalStack()

        if trends.topSymptomCategories.isEmpty {
            let state = StateView(model: .empty(
                title: "No symptoms yet",
                message: "No symptom text was captured in this window."
            ))
            return UIFactory.card(state)
        }

        let top = trends.topSymptomCategories.prefix(5)
        for (category, count) in top {
            let title = category.replacingOccurrences(of: "_", with: " ").capitalized

            let daily = trends.symptomCategoryDaily[category] ?? []
            let values = daily.map { CGFloat($0.value) }

            let rowStack = UIStackView()
            rowStack.axis = .vertical
            rowStack.spacing = UIFactory.Theme.Spacing.s

            let header = UIFactory.keyValueRow(title: title, value: "\(count)")
            rowStack.addArrangedSubview(header)

            let spark = SparklineView(
                values: values,
                strokeColor: UIFactory.Theme.Color.textSecondary,
                accessibilityLabelText: "\(title) trend",
                accessibilityValueText: "Daily frequency over time.",
                accessibilityHintText: "Chart of symptom frequency over time."
            )
            spark.heightAnchor.constraint(equalToConstant: 34).isActive = true
            rowStack.addArrangedSubview(spark)

            stack.addArrangedSubview(rowStack)
        }

        return UIFactory.card(stack)
    }

    private func sharingCard(trends: CheckInTrendsProvider.PersonTrends) -> UIView {
        let stack = UIFactory.verticalStack(spacing: UIFactory.Theme.Spacing.m)

        let blurb = UILabel()
        blurb.numberOfLines = 0
        blurb.textColor = UIFactory.Theme.Color.textSecondary
        blurb.font = UIFactory.Theme.Font.preferred(.subheadline)
        blurb.adjustsFontForContentSizeCategory = true
        blurb.text = "Email a monthly PDF of pain, mood, and top symptom trends. Nothing is sent unless you opt in and press send."
        stack.addArrangedSubview(blurb)

        let toggleRow = UIStackView()
        toggleRow.axis = .horizontal
        toggleRow.alignment = .center
        toggleRow.spacing = UIFactory.Theme.Spacing.m

        let toggleLabel = UILabel()
        toggleLabel.text = "Monthly summary"
        toggleLabel.font = UIFactory.Theme.Font.preferred(.body)
        toggleLabel.adjustsFontForContentSizeCategory = true
        toggleRow.addArrangedSubview(toggleLabel)
        toggleRow.addArrangedSubview(shareToggle)
        stack.addArrangedSubview(toggleRow)

        let recipientLabel = UILabel()
        recipientLabel.text = "Share with (emails)"
        recipientLabel.font = UIFactory.Theme.Font.preferred(.body)
        recipientLabel.adjustsFontForContentSizeCategory = true

        let recipientStack = UIFactory.verticalStack(spacing: UIFactory.Theme.Spacing.s)
        recipientStack.addArrangedSubview(recipientLabel)
        recipientStack.addArrangedSubview(recipientsField)
        stack.addArrangedSubview(recipientStack)

        stack.addArrangedSubview(shareStatusLabel)
        stack.addArrangedSubview(shareNowButton)

        return UIFactory.card(stack)
    }

    @objc private func sharingToggleChanged(_ sender: UISwitch) {
        sharingPreferences.isEnabled = sender.isOn
        savePreferences()
        updateSharingUI()
    }

    @objc private func shareNowTapped(_ sender: UIButton) {
        guard let trends = currentTrends else {
            present(appError: .operation(.shareSummary, underlying: nil))
            return
        }
        if sharingPreferences.recipients.isEmpty {
            showToast(message: "Add at least one email to share.")
            return
        }
        shareSummary(using: trends)
    }

    @objc private func shareNowFromNav() {
        shareNowTapped(shareNowButton)
    }

    private func shareSummary(using trends: CheckInTrendsProvider.PersonTrends) {
        do {
            let url = try pdfGenerator.makePDF(person: person, trends: trends, windowDays: windowDays)
            pendingShareURL = url
            presentShareController(for: url, trends: trends)
        } catch {
            present(appError: AppError(operation: .shareSummary, underlying: error))
        }
    }

    private func presentShareController(for url: URL, trends: CheckInTrendsProvider.PersonTrends) {
        let subjectName = person.name?.isEmpty == false ? person.name! : "Patient"
        let windowText = "\(statusDateFormatter.string(from: trends.windowStart)) – \(statusDateFormatter.string(from: trends.windowEnd))"
        let body = """
        Attached is the last \(windowDays)-day mood, pain, and symptom summary for \(subjectName).
        Window: \(windowText)
        """

        if MFMailComposeViewController.canSendMail() {
            let mail = MFMailComposeViewController()
            mail.mailComposeDelegate = self
            mail.setSubject("Monthly summary – \(subjectName)")
            mail.setToRecipients(sharingPreferences.recipients)
            mail.setMessageBody(body, isHTML: false)
            if let data = try? Data(contentsOf: url) {
                mail.addAttachmentData(data, mimeType: "application/pdf", fileName: url.lastPathComponent)
            }
            present(mail, animated: true)
            return
        }

        let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        activity.completionWithItemsHandler = { [weak self] _, completed, _, _ in
            self?.handleShareCompletion(completed: completed)
        }
        if let popover = activity.popoverPresentationController {
            popover.sourceView = shareNowButton
            popover.sourceRect = shareNowButton.bounds
        }
        present(activity, animated: true)
    }

    private func handleShareCompletion(completed: Bool) {
        if completed {
            sharingPreferences.lastSentAt = Date()
            savePreferences()
            updateSharingUI()
        }
        cleanupPendingShareURL()
    }

    private func cleanupPendingShareURL() {
        if let url = pendingShareURL {
            try? FileManager.default.removeItem(at: url)
        }
        pendingShareURL = nil
    }

    private func savePreferences() {
        guard let id = person.id else { return }
        sharingStore.save(sharingPreferences, for: id)
    }

    private func updateSharingUI(now: Date = Date()) {
        shareToggle.isOn = sharingPreferences.isEnabled
        recipientsField.text = sharingPreferences.recipients.joined(separator: ", ")

        let nextDate = sharingStore.nextSendDate(for: sharingPreferences, now: now)
        if !sharingPreferences.isEnabled {
            shareStatusLabel.text = "Opt in to send a monthly PDF to saved email recipients."
        } else if sharingPreferences.recipients.isEmpty {
            shareStatusLabel.text = "Add at least one email to send the monthly summary."
        } else if let nextDate {
            let readyText = now >= nextDate ? "Ready to send now." : "Next send after \(statusDateFormatter.string(from: nextDate))."
            shareStatusLabel.text = readyText
        } else {
            shareStatusLabel.text = "Ready to send."
        }

        shareNowButton.isEnabled = sharingPreferences.isEnabled && !sharingPreferences.recipients.isEmpty
        shareNowButton.alpha = shareNowButton.isEnabled ? 1 : 0.5
    }

    private func maybePromptMonthlyShare(now: Date = Date()) {
        guard !hasPromptedThisSession,
              let trends = currentTrends,
              sharingPreferences.isEnabled,
              !sharingPreferences.recipients.isEmpty,
              sharingStore.isDueForSend(sharingPreferences, now: now) else { return }

        hasPromptedThisSession = true
        let alert = AlertFactory.confirmAlert(
            title: "Send monthly summary?",
            message: "Share the latest \(windowDays)-day PDF with your saved contacts.",
            confirmTitle: "Send",
            cancelTitle: "Not now",
            isDestructive: false
        ) { [weak self] in
            guard let self else { return }
            self.shareSummary(using: trends)
        }
        present(alert, animated: true)
    }

    private func painTrendAccessibility(series: [CheckInTrendsProvider.Point]) -> String {
        guard let first = series.first, let last = series.last else { return "No data" }
        let start = Int(first.value.rounded())
        let end = Int(last.value.rounded())
        let direction: String
        if end > start { direction = "increasing" }
        else if end < start { direction = "decreasing" }
        else { direction = "stable" }
        return "Latest \(end) out of 10. Trend is \(direction)." 
    }
    private func bucketTitle<T>(_ bucket: T) -> String {
        if let b = bucket as? EnergyBucket { return b.displayText }
        if let b = bucket as? MoodBucket { return b.displayText }
        return String(describing: bucket)
    }
}

// MARK: - Lightweight charts

private final class SparklineView: UIView {
    private let values: [CGFloat]
    private let strokeColor: UIColor
    private let accessibilityValueText: String

    init(values: [CGFloat],
         strokeColor: UIColor,
         accessibilityLabelText: String = "Trend",
         accessibilityValueText: String = "",
         accessibilityHintText: String? = nil) {
        self.values = values
        self.strokeColor = strokeColor
        self.accessibilityValueText = accessibilityValueText
        super.init(frame: .zero)
        backgroundColor = .clear
        isAccessibilityElement = true
        accessibilityTraits = [.image]
        accessibilityLabel = accessibilityLabelText
        accessibilityValue = accessibilityValueText
        accessibilityHint = accessibilityHintText
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        guard values.count >= 2 else {
            // Draw a faint baseline.
            let p = UIBezierPath()
            p.move(to: CGPoint(x: rect.minX, y: rect.midY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            strokeColor.withAlphaComponent(0.2).setStroke()
            p.lineWidth = 2
            p.stroke()
            return
        }

        let minV = values.min() ?? 0
        let maxV = values.max() ?? 1
        let range = max(0.0001, maxV - minV)

        let inset: CGFloat = 2
        let w = rect.width - inset * 2
        let h = rect.height - inset * 2

        func point(at index: Int) -> CGPoint {
            let x = inset + (CGFloat(index) / CGFloat(values.count - 1)) * w
            let norm = (values[index] - minV) / range
            let y = rect.maxY - inset - norm * h
            return CGPoint(x: x, y: y)
        }

        let path = UIBezierPath()
        path.move(to: point(at: 0))
        for i in 1..<values.count {
            path.addLine(to: point(at: i))
        }

        strokeColor.setStroke()
        path.lineWidth = 2
        path.lineJoinStyle = .round
        path.lineCapStyle = .round
        path.stroke()
    }
}

private final class DistributionRow: UIView {
    private let titleLabel = UILabel()
    private let valueLabel = UILabel()
    private let bar = UIProgressView(progressViewStyle: .default)

    init(title: String, valueText: String, fraction: CGFloat) {
        super.init(frame: .zero)

        titleLabel.text = title
        titleLabel.font = UIFactory.Theme.Font.preferred(.body)
        titleLabel.adjustsFontForContentSizeCategory = true

        valueLabel.text = valueText
        valueLabel.font = UIFactory.Theme.Font.preferred(.body)
        valueLabel.adjustsFontForContentSizeCategory = true
        valueLabel.textColor = UIFactory.Theme.Color.textSecondary
        valueLabel.setContentHuggingPriority(.required, for: .horizontal)

        bar.progress = Float(max(0, min(1, fraction)))
        bar.trackTintColor = UIFactory.Theme.Color.separator.withAlphaComponent(0.35)
        bar.progressTintColor = UIFactory.Theme.Color.accent

        isAccessibilityElement = true
        accessibilityLabel = "\(title)"
        accessibilityValue = valueText

        let header = UIStackView(arrangedSubviews: [titleLabel, valueLabel])
        header.axis = .horizontal
        header.alignment = .firstBaseline

        let stack = UIStackView(arrangedSubviews: [header, bar])
        stack.axis = .vertical
        stack.spacing = UIFactory.Theme.Spacing.s
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - Delegates

extension PersonTrendsViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        let normalized = sharingStore.normalizeRecipients(from: textField.text)
        sharingPreferences.recipients = normalized
        updateSharingUI()
        savePreferences()
    }
}

extension PersonTrendsViewController: MFMailComposeViewControllerDelegate {
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true) { [weak self] in
            guard let self else { return }
            let completed = (result == .sent || result == .saved)
            self.handleShareCompletion(completed: completed)
            if let error {
                self.present(appError: AppError(operation: .shareSummary, underlying: error))
            }
        }
    }
}
