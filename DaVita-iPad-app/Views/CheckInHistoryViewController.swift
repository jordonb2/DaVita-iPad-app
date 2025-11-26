import UIKit
import CoreData
import Foundation

/// Admin-only multi-visit check-in history.
final class CheckInHistoryViewController: StandardTableViewController {
    private let context: NSManagedObjectContext

    /// Each section is a person, with their check-in records sorted newest first.
    private var sections: [(person: Person, records: [CheckInRecord])] = []

    private lazy var dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    init(context: NSManagedObjectContext = CoreDataStack.shared.viewContext) {
        self.context = context
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) {
        self.context = CoreDataStack.shared.viewContext
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Visit History"
        view.backgroundColor = .systemBackground

        tableView.dataSource = self
        tableView.delegate = self
        TableStyler.applyHistoryStyle(to: tableView)

        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Refresh", style: .plain, target: self, action: #selector(refreshTapped))

        loadSections()
    }

    @objc private func refreshTapped() {
        loadSections()
    }

    private func loadSections() {
        let fetch: NSFetchRequest<Person> = Person.fetchRequest()
        fetch.sortDescriptors = [
            NSSortDescriptor(key: "name", ascending: true),
            NSSortDescriptor(key: "createdAt", ascending: false)
        ]

        do {
            let people = try context.fetch(fetch)
            sections = people.map { person in
                let recordSet = (person.checkInRecords as? Set<CheckInRecord>) ?? []
                let records = recordSet.sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
                return (person, records)
            }
            tableView.reloadData()
        } catch {
            print("History fetch error: \(error)")
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

        let energyText = record.energyLevel?.isEmpty == false ? "Energy \(record.energyLevel!)" : "Energy —"
        let moodText = record.mood?.isEmpty == false ? "Mood \(record.mood!)" : "Mood —"

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
