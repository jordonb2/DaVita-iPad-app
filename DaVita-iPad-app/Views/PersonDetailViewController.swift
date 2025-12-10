import UIKit
import CoreData

/// Simple detail screen for a person, with actions to edit or drill into history.
final class PersonDetailViewController: ScrolledStackViewController {

    private let person: Person

    var onEditTapped: ((Person) -> Void)?
    var onHistoryTapped: ((Person) -> Void)?
    var onTimelineTapped: ((Person) -> Void)?
    var onTrendsTapped: ((Person) -> Void)?

    private static let dobFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    init(person: Person) {
        self.person = person
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = person.name ?? "Person"
        view.backgroundColor = .systemBackground

        render()
        configureNavItems()
    }

    private func configureNavItems() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Edit", style: .plain, target: self, action: #selector(editTapped))
        navigationItem.rightBarButtonItem?.accessibilityLabel = "Edit person"
    }

    private func render() {
        resetContentStack()

        if person.managedObjectContext == nil || person.isDeleted {
            contentStackView.addArrangedSubview(
                StateView(model: .error(
                    title: "Person unavailable",
                    message: "This record is no longer available.",
                    actionTitle: "Go back",
                    onAction: { [weak self] in
                        self?.navigationController?.popViewController(animated: true)
                    }
                ))
            )
            return
        }

        let hasAnyDetail = (person.name?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false) ||
            person.dob != nil ||
            person.genderEnum != nil

        if !hasAnyDetail {
            contentStackView.addArrangedSubview(
                StateView(model: .empty(
                    title: "No details yet",
                    message: "Add details for this person to see them here.",
                    actionTitle: "Edit person",
                    onAction: { [weak self] in
                        guard let self else { return }
                        self.onEditTapped?(self.person)
                    }
                ))
            )
            return
        }

        contentStackView.addArrangedSubview(UIFactory.sectionHeader(text: "Details"))

        let name = person.name ?? "—"
        contentStackView.addArrangedSubview(UIFactory.keyValueRow(title: "Name", value: name))

        if let dob = person.dob {
            contentStackView.addArrangedSubview(UIFactory.keyValueRow(title: "DOB", value: Self.dobFormatter.string(from: dob)))
        } else {
            contentStackView.addArrangedSubview(UIFactory.keyValueRow(title: "DOB", value: "—"))
        }

        let gender = person.genderEnum?.displayText ?? "—"
        contentStackView.addArrangedSubview(UIFactory.keyValueRow(title: "Gender", value: gender))

        contentStackView.addArrangedSubview(UIFactory.sectionHeader(text: "Actions", textStyle: .headline))

        let historyButton = UIFactory.roundedActionButton(title: "View Visit History")
        historyButton.addTarget(self, action: #selector(historyTapped), for: .touchUpInside)
        historyButton.isAccessibilityElement = true
        historyButton.accessibilityLabel = "View visit history"
        historyButton.accessibilityHint = "Shows this person's past check-ins."
        contentStackView.addArrangedSubview(historyButton)

        let timelineButton = UIFactory.roundedActionButton(title: "View Timeline")
        timelineButton.addTarget(self, action: #selector(timelineTapped), for: .touchUpInside)
        timelineButton.isAccessibilityElement = true
        timelineButton.accessibilityLabel = "View timeline"
        timelineButton.accessibilityHint = "Unified view of check-ins, notes, and escalations."
        contentStackView.addArrangedSubview(timelineButton)

        let trendsButton = UIFactory.roundedActionButton(title: "View Trends")
        trendsButton.addTarget(self, action: #selector(trendsTapped), for: .touchUpInside)
        trendsButton.isAccessibilityElement = true
        trendsButton.accessibilityLabel = "View trends"
        trendsButton.accessibilityHint = "Shows pain trend, energy/mood distributions, and symptom frequency over time."
        contentStackView.addArrangedSubview(trendsButton)
    }

    @objc private func editTapped() {
        onEditTapped?(person)
    }

    @objc private func historyTapped() {
        onHistoryTapped?(person)
    }

    @objc private func timelineTapped() {
        onTimelineTapped?(person)
    }

    @objc private func trendsTapped() {
        onTrendsTapped?(person)
    }
}


// MARK: - Patient timeline

final class PatientTimelineViewController: StandardTableViewController {

    private enum Filter: Int, CaseIterable {
        case all
        case checkIns
        case notes
        case escalations

        var title: String {
            switch self {
            case .all: return "All"
            case .checkIns: return "Check-ins"
            case .notes: return "Notes"
            case .escalations: return "Escalations"
            }
        }
    }

    private enum ItemType {
        case checkIn
        case note
        case escalation
    }

    private struct Item {
        let date: Date
        let type: ItemType
        let title: String
        let subtitle: String?
        let detail: String?
    }

    private let person: Person
    private let checkInRepo: CheckInRepository
    private let escalationStore: EscalationStateStoring

    private var items: [Item] = []
    private var filteredItems: [Item] = []
    private var filter: Filter = .all

    private static let dateTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    private lazy var filterControl: UISegmentedControl = {
        let control = UISegmentedControl(items: Filter.allCases.map { $0.title })
        control.selectedSegmentIndex = filter.rawValue
        control.addTarget(self, action: #selector(filterChanged(_:)), for: .valueChanged)
        control.accessibilityLabel = "Timeline quick filter"
        return control
    }()

    init(person: Person,
         checkInRepo: CheckInRepository,
         escalationStore: EscalationStateStoring = EscalationStateStore()) {
        self.person = person
        self.checkInRepo = checkInRepo
        self.escalationStore = escalationStore
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let name = person.name?.trimmingCharacters(in: .whitespacesAndNewlines)
        title = (name?.isEmpty == false) ? "\(name!) Timeline" : "Timeline"
        view.backgroundColor = .systemBackground

        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "timelineCell")
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 72

        navigationItem.titleView = filterControl
        addRefreshButton(selector: #selector(refreshTapped))

        reloadTimeline()
    }

    @objc private func filterChanged(_ sender: UISegmentedControl) {
        filter = Filter(rawValue: sender.selectedSegmentIndex) ?? .all
        applyFilter()
    }

    @objc private func refreshTapped() {
        reloadTimeline()
    }

    private func reloadTimeline() {
        tableView.setBackgroundState(.loading(title: "Loading timeline…"))
        guard person.managedObjectContext != nil else {
            tableView.setBackgroundState(.error(title: "Person unavailable", message: "This record is no longer available."))
            return
        }

        do {
            let records = try checkInRepo.fetchHistory(for: person, filter: CheckInHistoryFilter(limit: 75))
            var combined = makeItems(from: records)
            combined.append(contentsOf: escalationItems())
            items = combined.sorted { $0.date > $1.date }
            applyFilter()
        } catch {
            let appError = AppError(operation: .loadHistory, underlying: error)
            present(appError: appError)
            let ui = appError.userFacing
            tableView.setBackgroundState(.error(title: ui.title, message: ui.message, actionTitle: "Retry", onAction: { [weak self] in
                self?.reloadTimeline()
            }))
        }
    }

    private func applyFilter() {
        switch filter {
        case .all:
            filteredItems = items
        case .checkIns:
            filteredItems = items.filter { $0.type == .checkIn }
        case .notes:
            filteredItems = items.filter { $0.type == .note }
        case .escalations:
            filteredItems = items.filter { $0.type == .escalation }
        }
        updateBackgroundState()
        tableView.reloadData()
    }

    private func updateBackgroundState() {
        guard filteredItems.isEmpty else {
            tableView.backgroundView = nil
            tableView.separatorStyle = .singleLine
            return
        }

        let message: String
        switch filter {
        case .all: message = "No timeline items yet."
        case .checkIns: message = "No check-ins match this filter."
        case .notes: message = "No notes captured yet."
        case .escalations: message = "No escalations have been triggered."
        }

        tableView.setBackgroundState(.empty(title: "Nothing here", message: message, actionTitle: "Clear filters", onAction: { [weak self] in
            guard let self else { return }
            self.filter = .all
            self.filterControl.selectedSegmentIndex = self.filter.rawValue
            self.applyFilter()
        }))
    }

    private func makeItems(from records: [CheckInRecord]) -> [Item] {
        var results: [Item] = []
        for record in records {
            guard let created = record.createdAt else { continue }

            let checkInSubtitle = displayText(for: record)
            let detail = detailText(for: record)
            results.append(Item(date: created, type: .checkIn, title: "Check-in", subtitle: checkInSubtitle, detail: detail))

            if let note = normalizedNote(record.teamNote) {
                results.append(Item(date: created, type: .note, title: "Team note", subtitle: note, detail: note))
            }
        }
        return results
    }

    private func escalationItems() -> [Item] {
        guard let personID = person.id else { return [] }
        let personName = person.name ?? "This client"

        return EscalationRuleEngine.ReasonKind.allCases.compactMap { reason in
            guard let when = escalationStore.lastNotified(personID: personID, reason: reason) else { return nil }
            let desc = escalationDescription(for: reason, personName: personName)
            return Item(date: when, type: .escalation, title: desc.title, subtitle: desc.body, detail: desc.body)
        }
    }

    private func displayText(for record: CheckInRecord) -> String {
        let painText = "Pain \(record.painLevel)"

        let energyText: String = {
            if let n = record.value(forKey: "energyBucket") as? NSNumber,
               let b = EnergyBucket(rawValue: n.int16Value) {
                return "Energy \(b.displayText)"
            }
            if let legacy = record.energyLevel, !legacy.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "Energy \(legacy)"
            }
            return "Energy —"
        }()

        let moodText: String = {
            if let n = record.value(forKey: "moodBucket") as? NSNumber,
               let b = MoodBucket(rawValue: n.int16Value) {
                return "Mood \(b.displayText)"
            }
            if let legacy = record.mood, !legacy.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "Mood \(legacy)"
            }
            return "Mood —"
        }()

        return "\(painText) • \(energyText) • \(moodText)"
    }

    private func detailText(for record: CheckInRecord) -> String? {
        var parts: [String] = []
        if let s = record.symptoms, !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append("Symptoms: \(s)")
        }
        if let c = record.concerns, !c.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append("Concerns: \(c)")
        }
        if let n = record.teamNote, !n.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append("Note: \(n)")
        }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: "\n")
    }

    private func normalizedNote(_ raw: String?) -> String? {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        return trimmed
    }

    private func escalationDescription(for reason: EscalationRuleEngine.ReasonKind, personName: String) -> (title: String, body: String) {
        switch reason {
        case .highPain:
            return ("High pain alert", "\(personName) reported pain above the escalation threshold.")
        case .lowMood:
            return ("Low mood alert", "Mood dropped to a concerning level for \(personName).")
        case .rapidPain:
            return ("Pain trending up", "Rapid pain increase triggered an escalation.")
        case .rapidMood:
            return ("Mood worsening", "Recent check-ins show a quick drop in mood.")
        }
    }

    private func symbolName(for type: ItemType) -> String {
        switch type {
        case .checkIn: return "heart.text.square"
        case .note: return "note.text"
        case .escalation: return "exclamationmark.triangle"
        }
    }

    private func dateText(for date: Date) -> String {
        Self.dateTimeFormatter.string(from: date)
    }
}

extension PatientTimelineViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        filteredItems.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = filteredItems[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "timelineCell", for: indexPath)
        var config = cell.defaultContentConfiguration()
        config.text = item.title

        let subtitleParts: [String] = {
            var parts: [String] = [dateText(for: item.date)]
            if let subtitle = item.subtitle, !subtitle.isEmpty {
                parts.append(subtitle)
            }
            return parts
        }()
        config.secondaryText = subtitleParts.joined(separator: " • ")
        config.secondaryTextProperties.numberOfLines = 3
        config.image = UIImage(systemName: symbolName(for: item.type))
        cell.accessoryType = (item.detail ?? item.subtitle) == nil ? .none : .disclosureIndicator
        cell.contentConfiguration = config
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = filteredItems[indexPath.row]
        guard let detail = item.detail ?? item.subtitle else { return }
        let alert = AlertFactory.okAlert(title: item.title, message: detail)
        present(alert, animated: true)
    }
}
