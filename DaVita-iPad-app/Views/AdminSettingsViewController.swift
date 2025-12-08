import UIKit

/// Admin-only settings surface for privacy screen, export defaults, and auto-logout timeout.
final class AdminSettingsViewController: UITableViewController {
    private enum Section: Int, CaseIterable {
        case privacy
        case export
        case autoLogout
        case reminders

        var title: String {
            switch self {
            case .privacy: return "Privacy"
            case .export: return "Export defaults"
            case .autoLogout: return "Auto-logout"
            case .reminders: return "Smart reminders"
            }
        }
    }

    private let adminSession: AdminSessioning
    private let reminderManager: SmartReminderManaging?

    private let exportOptions: [(title: String, raw: Int, seconds: TimeInterval?)] = [
        ("All history", 0, nil),
        ("Last 30 days", 1, 30 * 24 * 60 * 60),
        ("Last 90 days", 2, 90 * 24 * 60 * 60)
    ]

    private let autoLogoutOptions: [(title: String, seconds: TimeInterval)] = [
        ("5 minutes", 5 * 60),
        ("10 minutes", 10 * 60),
        ("15 minutes", 15 * 60)
    ]

    init(adminSession: AdminSessioning,
         reminderManager: SmartReminderManaging? = nil) {
        self.adminSession = adminSession
        self.reminderManager = reminderManager
        super.init(style: .insetGrouped)
        title = "Admin Settings"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let section = Section(rawValue: section) else { return 0 }
        switch section {
        case .privacy: return 1
        case .export: return 1
        case .autoLogout: return 1
        case .reminders: return 1
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        Section(rawValue: section)?.title
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        guard let section = Section(rawValue: indexPath.section) else { return cell }
        cell.selectionStyle = .none

        switch section {
        case .privacy:
            cell.textLabel?.text = "Privacy screen"
            let toggle = UISwitch()
            toggle.isOn = AdminSettings.privacyScreenEnabled
            toggle.addTarget(self, action: #selector(privacyToggled(_:)), for: .valueChanged)
            cell.accessoryView = toggle

        case .export:
            cell.textLabel?.text = "Default export scope"
            let control = UISegmentedControl(items: exportOptions.map { $0.title })
            let saved = AdminSettings.defaultExportScopeRaw
            control.selectedSegmentIndex = (0..<exportOptions.count).contains(saved) ? saved : 0
            control.addTarget(self, action: #selector(exportScopeChanged(_:)), for: .valueChanged)
            control.translatesAutoresizingMaskIntoConstraints = false
            cell.contentView.addSubview(control)
            NSLayoutConstraint.activate([
                control.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
                control.trailingAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.trailingAnchor)
            ])

        case .autoLogout:
            cell.textLabel?.text = "Auto-logout after"
            let control = UISegmentedControl(items: autoLogoutOptions.map { $0.title })
            let saved = AdminSettings.autoLogoutSeconds
            let selectedIndex = autoLogoutOptions.firstIndex(where: { option in
                guard let saved else { return false }
                return abs(option.seconds - saved) < 0.1
            }) ?? 0
            control.selectedSegmentIndex = selectedIndex
            control.addTarget(self, action: #selector(autoLogoutChanged(_:)), for: .valueChanged)
            control.translatesAutoresizingMaskIntoConstraints = false
            cell.contentView.addSubview(control)
            NSLayoutConstraint.activate([
                control.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
                control.trailingAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.trailingAnchor)
            ])

        case .reminders:
            cell.textLabel?.text = "Smart reminders"
            cell.accessoryType = .disclosureIndicator
            cell.selectionStyle = .default
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let section = Section(rawValue: indexPath.section) else { return }
        switch section {
        case .reminders:
            guard let reminderManager else { return }
            let vc = SmartRemindersViewController(manager: reminderManager)
            navigationController?.pushViewController(vc, animated: true)
        default:
            break
        }
    }

    @objc private func privacyToggled(_ sender: UISwitch) {
        AdminSettings.privacyScreenEnabled = sender.isOn
    }

    @objc private func exportScopeChanged(_ sender: UISegmentedControl) {
        AdminSettings.defaultExportScopeRaw = sender.selectedSegmentIndex
    }

    @objc private func autoLogoutChanged(_ sender: UISegmentedControl) {
        guard sender.selectedSegmentIndex < autoLogoutOptions.count else { return }
        let seconds = autoLogoutOptions[sender.selectedSegmentIndex].seconds
        AdminSettings.autoLogoutSeconds = seconds
        adminSession.configureAutoLogout(inactivityTimeoutSeconds: seconds)
    }
}


