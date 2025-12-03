import UIKit

/// Per-person trends computed from check-in history.
final class PersonTrendsViewController: ScrolledStackViewController {

    private let person: Person
    private let trendsProvider: CheckInTrendsProviding

    private let windowDays: Int

    private enum ViewState {
        case loading
        case empty
        case loaded(CheckInTrendsProvider.PersonTrends)
        case error(title: String, message: String)
    }

    private var state: ViewState = .loading

    init(person: Person,
         windowDays: Int = 30,
         trendsProvider: CheckInTrendsProviding) {
        self.person = person
        self.windowDays = windowDays
        self.trendsProvider = trendsProvider
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Trends"
        view.backgroundColor = UIFactory.Theme.Color.surface

        state = .loading
        render()
        reloadTrends()
    }

    private func reloadTrends() {
        let trends: CheckInTrendsProvider.PersonTrends
        do {
            trends = try trendsProvider.computeTrends(for: person, windowDays: windowDays, maxRecords: 250)
        } catch {
            AppLog.persistence.error("Failed to compute trends: \(error, privacy: .public)")
            present(appError: AppError(operation: .loadTrends, underlying: error))
            state = .error(title: "Couldn't load trends", message: "Please try again.")
            render()
            return
        }

        state = (trends.totalRecordsInWindow == 0) ? .empty : .loaded(trends)
        render()
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

        case .error(let title, let message):
            contentStackView.addArrangedSubview(
                StateView(model: .error(
                    title: title,
                    message: message,
                    actionTitle: "Retry",
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
    }

    private func painCard(series: [CheckInTrendsProvider.Point]) -> UIView {
        let stack = UIFactory.verticalStack()

        let values = series.map { CGFloat($0.value) }
        let spark = SparklineView(values: values, strokeColor: UIFactory.Theme.Color.accent, accessibilityValueText: painTrendAccessibility(series: series))
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

            let spark = SparklineView(values: values, strokeColor: UIFactory.Theme.Color.textSecondary, accessibilityValueText: "Daily frequency over time")
            spark.heightAnchor.constraint(equalToConstant: 34).isActive = true
            rowStack.addArrangedSubview(spark)

            stack.addArrangedSubview(rowStack)
        }

        return UIFactory.card(stack)
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

    init(values: [CGFloat], strokeColor: UIColor, accessibilityValueText: String = "") {
        self.values = values
        self.strokeColor = strokeColor
        self.accessibilityValueText = accessibilityValueText
        super.init(frame: .zero)
        backgroundColor = .clear
        isAccessibilityElement = true
        accessibilityTraits = [.image]
        accessibilityLabel = "Trend"
        accessibilityValue = accessibilityValueText
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
