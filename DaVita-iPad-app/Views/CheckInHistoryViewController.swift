import UIKit
import CoreData
import Foundation

/// Admin-only multi-visit check-in history.
///
/// Uses `NSFetchedResultsController` for live-updating results.
final class CheckInHistoryViewController: StandardTableViewController, NSFetchedResultsControllerDelegate {
    private let checkInRepo: CheckInHistoryRepositorying
    private let personFilter: Person?

    private var frc: NSFetchedResultsController<CheckInRecord>?

    // MARK: - Filtering

    private enum HistoryScope {
        case all
        case last(Int)
        case dateRange(start: Date, end: Date)
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
            // NSFetchedResultsController applies fetchLimit to the whole fetch, not per section.
            // Only enable in single-person mode.
            if personFilter != nil {
                f.limit = n
            } else {
                f.limit = nil
            }
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

    init(person: Person? = nil, checkInRepo: CheckInHistoryRepositorying) {
        self.checkInRepo = checkInRepo
        self.personFilter = person
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
        configureFRC()
    }

    // MARK: - FRC

    private func configureFRC() {
        do {
            frc = try checkInRepo.makeHistoryFRC(person: personFilter, filter: currentHistoryFilter, delegate: self)
            tableView.reloadData()
        } catch {
            AppLog.persistence.error("History FRC setup error: \(error, privacy: .public)")
            showToast(message: "Couldn't load history. Please try again.")
            frc = nil
            tableView.reloadData()
        }
    }

    @objc private func refreshTapped() {
        configureFRC()
    }

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.reloadData()
    }

    // MARK: - Filter UI

    private func configureFilterUI() {
        // Keyword search (symptoms/concerns)
        let search = UISearchController(searchResultsController: nil)
        search.obscuresBackgroundDuringPresentation = false
        search.searchBar.placeholder = "Search symptoms or concerns"
        search.searchBar.accessibilityIdentifier = "history.search"
        search.searchResultsUpdater = self
        navigationItem.searchController = search
        navigationItem.hidesSearchBarWhenScrolling = false

        let filterButton = UIBarButtonItem(title: "Filter", style: .plain, target: self, action: nil)
        filterButton.accessibilityLabel = "History filter"
        filterButton.accessibilityHint = "Filter history by date or keyword"
        filterButton.accessibilityIdentifier = "history.filter"
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
            self?.configureFRC()
        }

        let last5 = UIAction(
            title: "Last 5 visits",
            attributes: (personFilter == nil ? [.disabled] : []) ,
            state: {
                if case .last(5) = scope { return .on }
                return .off
            }()
        ) { [weak self] _ in
            self?.scope = .last(5)
            self?.navigationItem.leftBarButtonItem?.menu = self?.makeScopeMenu()
            self?.configureFRC()
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
            self?.navigationItem.leftBarButtonItem?.menu = self?.makeScopeMenu()
            self?.configureFRC()
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
            self.configureFRC()
        }

        vc.onClear = { [weak self] in
            guard let self else { return }
            self.scope = .all
            self.navigationItem.leftBarButtonItem?.menu = self.makeScopeMenu()
            self.configureFRC()
        }

        present(nav, animated: true)
    }

    // MARK: - Display helpers

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
}

// MARK: - UITableView

extension CheckInHistoryViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return frc?.sections?.count ?? 0
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if let personFilter {
            return personFilter.name ?? "Unnamed Person"
        }
        return frc?.sections?[section].name
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let sectionInfo = frc?.sections?[section] else { return 0 }
        return max(sectionInfo.numberOfObjects, 1)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "historyCell", for: indexPath)
        var config = cell.defaultContentConfiguration()

        guard let frc, let sectionInfo = frc.sections?[indexPath.section] else {
            config.text = "No data"
            cell.selectionStyle = .none
            cell.contentConfiguration = config
            return cell
        }

        if sectionInfo.numberOfObjects == 0 {
            config.text = "No check-ins yet"
            config.secondaryText = nil
            cell.selectionStyle = .none
            cell.accessoryType = .none
            cell.contentConfiguration = config
            return cell
        }

        let record = frc.object(at: indexPath)
        let dateText = record.createdAt.map { dateFormatter.string(from: $0) } ?? "Unknown date"
        config.text = dateText
        config.secondaryText = displayText(for: record)
        config.secondaryTextProperties.numberOfLines = 2

        cell.selectionStyle = .default
        cell.accessoryType = detailText(for: record) == nil ? .none : .disclosureIndicator
        cell.contentConfiguration = config
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let frc, let sectionInfo = frc.sections?[indexPath.section], sectionInfo.numberOfObjects > 0 else {
            return
        }

        let record = frc.object(at: indexPath)
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
            self.configureFRC()
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
        stack.spacing = UIFactory.Theme.Spacing.l
        stack.translatesAutoresizingMaskIntoConstraints = false

        let startLabel = UILabel()
        startLabel.text = "Start"
        startLabel.font = UIFont.preferredFont(forTextStyle: .headline)
        startLabel.adjustsFontForContentSizeCategory = true

        let endLabel = UILabel()
        endLabel.text = "End"
        endLabel.font = UIFont.preferredFont(forTextStyle: .headline)
        endLabel.adjustsFontForContentSizeCategory = true

        stack.addArrangedSubview(startLabel)
        stack.addArrangedSubview(startPicker)
        stack.addArrangedSubview(endLabel)
        stack.addArrangedSubview(endPicker)

        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: UIFactory.Theme.Spacing.xl)
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
