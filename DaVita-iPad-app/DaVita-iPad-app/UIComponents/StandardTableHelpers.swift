import UIKit

/// Base class for full-screen table UIs with standard padding and optional refresh button.
/// Subclasses are responsible for setting `tableView.dataSource` / `tableView.delegate`.
class StandardTableViewController: UIViewController {

    let tableView: UITableView

    /// Override to customize style.
    init(style: UITableView.Style = .insetGrouped) {
        self.tableView = UITableView(frame: .zero, style: style)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        self.tableView = UITableView(frame: .zero, style: .insetGrouped)
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureTableLayout()
    }

    func configureTableLayout() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    func addRefreshButton(title: String = "Refresh", selector: Selector) {
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: title, style: .plain, target: self, action: selector)
    }
}

/// Styling helpers for table-based screens.
enum TableStyler {
    static func applyPeopleListStyle(to tableView: UITableView) {
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.separatorInset = UIEdgeInsets(top: 0, left: UIFactory.Theme.Spacing.xxl, bottom: 0, right: UIFactory.Theme.Spacing.xxl)
        tableView.separatorColor = UIFactory.Theme.Color.surfaceElevated
        tableView.backgroundColor = UIColor.systemGroupedBackground
        tableView.contentInset = UIEdgeInsets(top: UIFactory.Theme.Spacing.m, left: 0, bottom: UIFactory.Theme.Spacing.huge, right: 0)
    }

    static func applyHistoryStyle(to tableView: UITableView) {
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "historyCell")
    }
}
