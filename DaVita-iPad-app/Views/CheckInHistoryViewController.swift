import UIKit
import CoreData
import Foundation

/// Admin-only multi-visit check-in history.
final class CheckInHistoryViewController: StandardTableViewController {
    private let context: NSManagedObjectContext
    private let checkInRepo: CheckInRepository
    private let personFilter: Person?

    /// Each section is a person, with their check-in records sorted newest first.
    private var sections: [(person: Person, records: [CheckInRecord])] = []


    // MARK: - Filtering

    private enum HistoryScope {
        case all
        case last(Int)
        case dateRange(start: Date, end: Date)

        var buttonTitle: String {
            switch self {
            case .all: return "All"
            case .last(let n): return "Last \(n)"
            case .dateRange: return "Date Range"
            }
        }
    }

    private var scope: HistoryScope = .all
    private var keyword: String? = nil
    private var pendingSearchWork: DispatchWorkItem?

    private var currentHistoryFilter: CheckInHistoryFilter {
        var f = CheckInHistoryFilter()
        f.keyword = keyword
        switch scope {
        case .all:
            f.limit = nil
            f.startDate = nil
            f.endDate = nil
        case .last(let n):
            f.limit = n
            f.startDate = nil
            f.endDate = nil
        case .dateRange(let start, let end):
            f.limit = nil
            f.startDate = start
            f.endDate = end
        }
        return f
    }

    private lazy var dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    init(person: Person? = nil, context: NSManagedObjectContext = CoreDataStack.shared.viewContext) {
        self.context = context
        self.checkInRepo = CheckInRepository(context: context)
        self.personFilter = person
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) {
        self.context = CoreDataStack.shared.viewContext
        self.checkInRepo = CheckInRepository(context: self.context)
        self.personFilter = nil
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        if let personFilter {
            title = "\(personFilter.name ?? "Person") History"
        } else {
            title = "Visit History"
        }
        view.backgroundColor = .systemBackground

        tableView.dataSource = self
        tableView.delegate = self
        TableStyler.applyHistoryStyle(to: tableView)

        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Refresh", style: .plain, target: self, action: #selector(refreshTapped))
        configureFilterUI()

        loadSections()
    }


    private func configureFilterUI() {
        // Keyword search (symptoms/concerns)
        let search = UISearchController(searchResultsController: nil)
        search.obscuresBackgroundDuringPresentation = false
        search.searchBar.placeholder = "Search symptoms or concerns"
        search.searchResultsUpdater = self
        navigationItem.searchController = search
        navigationItem.hidesSearchBarWhenScrolling = false

        // Scope menu (all / last 5 / date range)
        let filterButton = UIBarButtonItem(title: "Filter", style: .plain, target: self, action: nil)
        filterButton.menu = makeScopeMenu()
        filterButton.primaryAction = nil
        navigationItem.leftBarButtonItem = filterButton
    }

    private func makeScopeMenu() -> UIMenu {
        let all = UIAction(title: "All visits", state: {
            if case .all = scope { return .on }
            return .off
        }()) { [weak self] _ in
            self?.scope = .all
            self?.navigationItem.leftBarButtonItem?.menu = self?.makeScopeMenu()
            self?.loadSections()
        }

        let last5 = UIAction(title: "Last 5 visits", state: {
            if case .last(5) = scope { return .on }
            return .off
        }()) { [weak self] _ in
            self?.scope = .last(5)
            self?.navigationItem.leftBarButtonItem?.menu = self?.makeScopeMenu()
            self?.loadSections()
        }

        let dateRange = UIAction(title: "Date range…", state: {
            if case .dateRange = scope { return .on }
            return .off
        }()) { [weak self] _ in
            self?.presentDateRangePicker()
        }

        let clearKeyword = UIAction(title: "Clear keyword", attributes: (keyword?.isEmpty == false ? [] : [.disabled])) { [weak self] _ in
            self?.keyword = nil
            self?.navigationItem.searchController?.searchBar.text = nil
            self?.loadSections()
        }

        return UIMenu(title: "History Filter", children: [all, last5, dateRange, clearKeyword])
    }

    private func presentDateRangePicker() {
        let vc = DateRangePickerViewController()
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .formSheet
        vc.onApply = { [weak self] start, end in
            guard let self else { return }
            self.scope = .dateRange(start: start, end: end)
            self.navigationItem.leftBarButtonItem?.menu = self.makeScopeMenu()
            self.loadSections()
        }
        vc.onClear = { [weak self] in
            guard let self else { return }
            self.scope = .all
            self.navigationItem.leftBarButtonItem?.menu = self.makeScopeMenu()
            self.loadSections()
        }
        present(nav, animated: true)
    }

    @objc private func refreshTapped() {
        loadSections()
    }

    private func loadSections() {
        if let personFilter {
            do {
                let records = try checkInRepo.fetchHistory(for: personFilter, filter: currentHistoryFilter)
                sections = [(personFilter, records)]
            } catch {
                AppLog.persistence.error("History fetch error: \(error, privacy: .public)")
            showToast(message: "Couldn't load history. Please try again.")
                showToast(message: "Couldn't load history. Please try again.")
                sections = [(personFilter, [])]
            }
            tableView.reloadData()
            return
        }

        let fetch: NSFetchRequest<Person> = Person.fetchRequest()
        fetch.sortDescriptors = [
            NSSortDescriptor(key: "name", ascending: true),
            NSSortDescriptor(key: "createdAt", ascending: false)
        ]

        do {
            let people = try context.fetch(fetch)
            sections = people.map { person in
                let records: [CheckInRecord]
                do {
                    records = try checkInRepo.fetchHistory(for: person, filter: currentHistoryFilter)
                } catch {
                    AppLog.persistence.error("History fetch error for person \(person.name ?? "Person", privacy: .private): \(error, privacy: .public)")
                    records = []
                }
                return (person, records)
            }
            tableView.reloadData()
        } catch {
            AppLog.persistence.error("History fetch error: \(error, privacy: .public)")
            showToast(message: "Couldn't load history. Please try again.")
            sections = []
            tableView.reloadData()
        }
    }

    private func displayText(for record: CheckInRecord) -> String {
        let painText: String
        if record.painLevel != 0 {
            painText = "Pain \(record.painLevel)"
        } else {
            painText = "Pain 0"
        }

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
        if parts.isEmpty { return nil }
        return parts.joined(separator: "\n")
    }
}

extension CheckInHistoryViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let person = sections[section].person
        return person.name ?? "Unnamed Person"
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let records = sections[section].records
        return max(records.count, 1)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "historyCell", for: indexPath)
        var config = cell.defaultContentConfiguration()

        let records = sections[indexPath.section].records
        if records.isEmpty {
            config.text = "No check-ins yet"
            config.secondaryText = nil
            cell.selectionStyle = .none
            cell.accessoryType = .none
        } else {
            let record = records[indexPath.row]
            let dateText = record.createdAt.map { dateFormatter.string(from: $0) } ?? "Unknown date"
            config.text = dateText
            config.secondaryText = displayText(for: record)
            config.secondaryTextProperties.numberOfLines = 2
            cell.selectionStyle = .default
            cell.accessoryType = detailText(for: record) == nil ? .none : .disclosureIndicator
        }

        cell.contentConfiguration = config
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let records = sections[indexPath.section].records
        guard !records.isEmpty else { return }

        let record = records[indexPath.row]
        guard let detail = detailText(for: record) else { return }

        let alert = AlertFactory.okAlert(title: "Check-in Details", message: detail)
        present(alert, animated: true)
    }
}

extension CheckInHistoryViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        pendingSearchWork?.cancel()

        let text = searchController.searchBar.text
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.keyword = text
            self.navigationItem.leftBarButtonItem?.menu = self.makeScopeMenu()
            self.loadSections()
        }
        pendingSearchWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
    }
}

private final class DateRangePickerViewController: UIViewController {
    var onApply: ((Date, Date) -> Void)?
    var onClear: (() -> Void)?

    private let startPicker = UIDatePicker()
    private let endPicker = UIDatePicker()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Date Range"
        view.backgroundColor = .systemBackground

        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(cancelTapped))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Apply", style: .done, target: self, action: #selector(applyTapped))

        let clear = UIBarButtonItem(title: "Clear", style: .plain, target: self, action: #selector(clearTapped))
        toolbarItems = [clear]
        navigationController?.isToolbarHidden = false

        startPicker.datePickerMode = .date
        endPicker.datePickerMode = .date
        startPicker.maximumDate = Date()
        endPicker.maximumDate = Date()
        endPicker.date = Date()
        startPicker.date = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false

        let startLabel = UILabel()
        startLabel.text = "Start"
        startLabel.font = UIFont.preferredFont(forTextStyle: .headline)

        let endLabel = UILabel()
        endLabel.text = "End"
        endLabel.font = UIFont.preferredFont(forTextStyle: .headline)

        stack.addArrangedSubview(startLabel)
        stack.addArrangedSubview(startPicker)
        stack.addArrangedSubview(endLabel)
        stack.addArrangedSubview(endPicker)

        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20)
        ])
    }

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }

    @objc private func applyTapped() {
        let start = min(startPicker.date, endPicker.date)
        let end = max(startPicker.date, endPicker.date)
        onApply?(start, end)
        dismiss(animated: true)
    }

    @objc private func clearTapped() {
        onClear?()
        dismiss(animated: true)
    }
}

