//
//  PeopleListViewController.swift
//  DaVita-iPad-app
//
//  Created by Jordon Bowen on 10/3/25.
//

import UIKit

 final class PeopleListViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    var router: AppRouting!
    var viewModel: PeopleListViewModel!
    
    // If your table view is the ROOT view, we can grab it like this:
    private var tableViewRef: UITableView { self.view as! UITableView }
    
    private let calendar = Calendar.current
    private var headerNeedsSizing: Bool = true
    private var headerLastSizedWidth: CGFloat = 0

    private enum ViewState {
        case loading
        case loaded
        case empty
        case error(AppError)
    }

    private var state: ViewState = .loading

    private lazy var landingHeaderView: LandingHeroHeaderView = {
        let header = LandingHeroHeaderView()
        header.onPrimaryTap = { [weak self] in
            self?.didTapAdd()
        }
        header.onSecondaryTap = { [weak self] in
            self?.scrollToLatestRecord()
        }
        return header
    }()

    private let analyticsButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        let image = UIImage(systemName: "ellipsis")
        button.setImage(image, for: .normal)
        button.tintColor = UIFactory.Theme.Color.textSecondary
        button.backgroundColor = UIFactory.Theme.Color.fabBackground
        button.layer.cornerRadius = UIFactory.Theme.CornerRadius.fab
        UIFactory.Theme.Shadow.fab.apply(to: button.layer)
        button.layer.zPosition = UIFactory.Theme.ZIndex.floating
        button.widthAnchor.constraint(equalToConstant: UIFactory.Theme.Metrics.fabSize).isActive = true
        button.heightAnchor.constraint(equalToConstant: UIFactory.Theme.Metrics.fabSize).isActive = true
        button.isAccessibilityElement = true
        button.accessibilityLabel = "Analytics"
        button.accessibilityIdentifier = "peopleList.analytics"
        button.accessibilityHint = "Admin login to view check-in analytics."
        return button
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        assert(router != nil, "PeopleListViewController.router must be injected by a coordinator")
        assert(viewModel != nil, "PeopleListViewController.viewModel must be injected by a coordinator")
        title = "People"
        view.backgroundColor = .systemBackground
        
        // + button programmatically (no storyboard dragging headaches)
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(didTapAdd)
        )
        navigationItem.rightBarButtonItem?.accessibilityIdentifier = "peopleList.add"

        configureAnalyticsButton()

        viewModel.onUserToast = { [weak self] message in
            self?.showToast(message: message)
        }
        viewModel.onUserAlert = { [weak self] title, message in
            self?.presentErrorAlert(title: title, message: message)
        }
        viewModel.onError = { [weak self] error in
            self?.state = .error(error)
            self?.updateListState()
            self?.present(appError: error)
        }
        
        let tableView = tableViewRef
        tableViewRef.accessibilityIdentifier = "peopleList.table"
        tableView.dataSource = self
        tableView.delegate = self
        TableStyler.applyPeopleListStyle(to: tableView)
        
        // Keep UI in-sync with FRC-driven model updates (no Combine).
        viewModel.onPeopleChanged = { [weak self] _ in
            guard let self else { return }
            self.state = self.viewModel.count == 0 ? .empty : .loaded
            self.updateListState()
            self.tableViewRef.reloadData()
            self.updateHeaderContent()
        }

        configureLandingHeader()
        // Ensure initial render reflects current data.
        state = .loading
        updateListState()
        state = viewModel.count == 0 ? .empty : .loaded
        updateListState()
        tableViewRef.reloadData()
        updateHeaderContent()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateHeaderHeightIfNeeded()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        // Dynamic Type / size class changes can affect the header's intrinsic height.
        headerNeedsSizing = true
        view.setNeedsLayout()
    }
    
    @objc private func didTapAdd() {
        router.showAddPerson(from: self) { [weak self] name, dob, gender, checkInData in
            self?.viewModel.add(name: name, gender: gender, dob: dob, checkInData: checkInData)
        }
    }

    private func updateListState() {
        switch state {
        case .loading:
            tableViewRef.setBackgroundState(.loading(title: "Loading people…"))

        case .empty:
            tableViewRef.setBackgroundState(
                .empty(
                    title: "No people yet",
                    message: "Tap + to add your first person.",
                    actionTitle: "Add person",
                    onAction: { [weak self] in self?.didTapAdd() }
                )
            )

        case .error:
            tableViewRef.setBackgroundState(
                .error(
                    title: "Couldn't load people",
                    message: "Please try again.",
                    actionTitle: "Retry",
                    onAction: { [weak self] in self?.viewModel.refresh() }
                )
            )

        case .loaded:
            tableViewRef.backgroundView = nil
            tableViewRef.separatorStyle = .singleLine
        }
    }
    
    // MARK: - UITableViewDataSource
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let person = viewModel.person(at: indexPath)
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        var config = cell.defaultContentConfiguration()
        config.text = person.name
        
        // Secondary text = DOB and Age if available
        if let info = person.dobAndAgeDisplay(now: Date(), calendar: calendar) {
            config.secondaryText = info.secondaryText
            cell.isAccessibilityElement = true
            cell.accessibilityLabel = info.accessibilityLabel
        } else {
            config.secondaryText = "DOB: —"

            let nameText = person.name ?? ""
            cell.isAccessibilityElement = true
            cell.accessibilityLabel = "\(nameText). Date of birth not available."
        }
        
        cell.contentConfiguration = config
        return cell
    }
    
    // MARK: - UITableViewDelegate (swipe to delete)
    func tableView(_ tableView: UITableView,
                   trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath)
     -> UISwipeActionsConfiguration? {
         let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, done in
             guard let self else { return }
             let person = self.viewModel.person(at: indexPath)
             let name = person.name ?? "this client"
             
             let alert = AlertFactory.confirmAlert(
                title: "Delete client?",
                message: "This will permanently remove \(name) from your records.",
                confirmTitle: "Delete",
                cancelTitle: "Cancel",
                isDestructive: true
             ) { [weak self] in
                 self?.viewModel.delete(person)
                 done(true)
             }
             self.present(alert, animated: true)
         }
         
         return UISwipeActionsConfiguration(actions: [deleteAction])
     }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let person = viewModel.person(at: indexPath)

        router.showPersonDetail(person, from: self) { [weak self] person, name, dob, gender, checkInData in
            self?.viewModel.update(person, name: name, gender: gender, dob: dob, checkInData: checkInData)
        }
    }

    // MARK: - Landing Header

    private func configureLandingHeader() {
        // `tableHeaderView` is frame-driven; keep autoresizing enabled so it spans the full table width.
        landingHeaderView.translatesAutoresizingMaskIntoConstraints = true
        landingHeaderView.autoresizingMask = [.flexibleWidth]
        tableViewRef.tableHeaderView = landingHeaderView
        updateHeaderContent()
    }

    private func updateHeaderContent() {
        landingHeaderView.apply(makeHeaderModel())
        headerNeedsSizing = true
        // Wait until we have a real table width; doing sizing in the next run loop avoids extra layout churn.
        DispatchQueue.main.async { [weak self] in
            self?.updateHeaderHeightIfNeeded(force: true)
        }
    }

    private func makeHeaderModel() -> LandingHeroHeaderView.Model {
        let total = viewModel.count
        let now = Date()
        let newThisWeek = viewModel.people.filter { person in
            guard let createdAt = person.createdAt else { return false }
            return calendar.isDate(createdAt, equalTo: now, toGranularity: .weekOfYear)
        }.count
        let returningClients = max(total - newThisWeek, 0)

        let metrics: [LandingHeroHeaderView.Metric] = [
            .init(title: "Active Clients", value: "\(total)", footnote: "managed in your hub"),
            .init(title: "New this week", value: "\(newThisWeek)", footnote: "freshly onboarded"),
            .init(title: "Follow ups", value: "\(returningClients)", footnote: "needing attention")
        ]

        let greeting = greetingText(for: now)

        return LandingHeroHeaderView.Model(
            greeting: greeting,
            headline: "Human-centered kidney care",
            subtitle: "Pick up right where you left off with a clean view of every client journey.",
            primaryButtonTitle: "Add Client",
            secondaryButtonTitle: total == 0 ? "Browse Empty List" : "Jump to Latest",
            metrics: metrics
        )
    }

    private func updateHeaderHeightIfNeeded(force: Bool = false) {
        guard let header = tableViewRef.tableHeaderView else { return }
        let width = tableViewRef.bounds.width
        guard width > 0 else { return }

        if !force && !headerNeedsSizing && abs(width - headerLastSizedWidth) < 0.5 {
            return
        }

        // Ensure the header has the correct width *before* we ask Auto Layout for its fitting height.
        if abs(header.frame.width - width) > 0.5 {
            var f = header.frame
            f.size.width = width
            // Keep a non-zero height so internal constraints can lay out.
            if f.size.height < 1 { f.size.height = 1 }
            header.frame = f
        }

        header.setNeedsLayout()
        header.layoutIfNeeded()

        let targetSize = CGSize(width: width, height: UIView.layoutFittingCompressedSize.height)
        let height = header.systemLayoutSizeFitting(
            targetSize,
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height

        var frame = header.frame
        let needsHeightUpdate = abs(frame.height - height) > 0.5
        let needsWidthUpdate = abs(frame.width - width) > 0.5
        if needsHeightUpdate || needsWidthUpdate {
            frame.size.height = height
            frame.size.width = width
            header.frame = frame
            tableViewRef.tableHeaderView = header
        }

        headerLastSizedWidth = width
        headerNeedsSizing = false
    }

    private func greetingText(for date: Date) -> String {
        let hour = calendar.component(.hour, from: date)
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Welcome back"
        }
    }

    private func scrollToLatestRecord() {
        guard viewModel.count > 0 else { return }
        let topIndex = IndexPath(row: 0, section: 0)
        tableViewRef.scrollToRow(at: topIndex, at: .top, animated: true)
    }

    private func configureAnalyticsButton() {
        view.addSubview(analyticsButton)
        NSLayoutConstraint.activate([
            analyticsButton.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            analyticsButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])
        analyticsButton.addTarget(self, action: #selector(analyticsTapped), for: .touchUpInside)
    }

    @objc private func analyticsTapped() {
        router.showAnalytics(from: self)
    }
}
