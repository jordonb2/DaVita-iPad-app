//
//  PeopleListViewController.swift
//  DaVita-iPad-app
//
//  Created by Jordon Bowen on 10/3/25.
//

import UIKit
import Combine

 final class PeopleListViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    var router: AppRouting = AppRouter.shared
    
    // If your table view is the ROOT view, we can grab it like this:
    private var tableViewRef: UITableView { self.view as! UITableView }
    
    private let viewModel = PeopleListViewModel()
    private var cancellables = Set<AnyCancellable>()
    private let calendar = Calendar.current

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
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = UIFactory.Theme.Metrics.fabShadowOpacity
        button.layer.shadowRadius = UIFactory.Theme.Metrics.fabShadowRadius
        button.layer.shadowOffset = UIFactory.Theme.Metrics.fabShadowOffset
        button.widthAnchor.constraint(equalToConstant: UIFactory.Theme.Metrics.fabSize).isActive = true
        button.heightAnchor.constraint(equalToConstant: UIFactory.Theme.Metrics.fabSize).isActive = true
        button.isAccessibilityElement = true
        button.accessibilityLabel = "Analytics"
        button.accessibilityHint = "Admin login to view check-in analytics."
        return button
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "People List"
        view.backgroundColor = .systemBackground
        
        // + button programmatically (no storyboard dragging headaches)
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(didTapAdd)
        )

        configureAnalyticsButton()

        viewModel.onUserToast = { [weak self] message in
            self?.showToast(message: message)
        }
        viewModel.onUserAlert = { [weak self] title, message in
            self?.presentErrorAlert(title: title, message: message)
        }
        
        let tableView = tableViewRef
        tableView.dataSource = self
        tableView.delegate = self
        TableStyler.applyPeopleListStyle(to: tableView)
        
        // Subscribe to Combine publisher to auto-reload on DB changes
        viewModel.$people
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.tableViewRef.reloadData()
                self.updateHeaderContent()
            }
            .store(in: &cancellables)

        configureLandingHeader()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateHeaderHeightIfNeeded()
    }
    
    @objc private func didTapAdd() {
        router.showAddPerson(from: self) { [weak self] name, dob, gender, checkInData in
            self?.viewModel.add(name: name, gender: gender, dob: dob, checkInData: checkInData)
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
        if let dob = person.dob {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            let dobString = formatter.string(from: dob)
            let calendar = Calendar.current
            let ageComponents = calendar.dateComponents([.year], from: dob, to: Date())
            let age = ageComponents.year ?? 0
            
            config.secondaryText = "DOB: \(dobString) — Age: \(age)"

            let nameText = person.name ?? ""
            cell.isAccessibilityElement = true
            cell.accessibilityLabel = "\(nameText). Date of birth \(dobString). Age \(age)."
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
        landingHeaderView.translatesAutoresizingMaskIntoConstraints = false
        tableViewRef.tableHeaderView = landingHeaderView
        updateHeaderContent()
    }

    private func updateHeaderContent() {
        landingHeaderView.apply(makeHeaderModel())
        updateHeaderHeightIfNeeded()
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

    private func updateHeaderHeightIfNeeded() {
        guard let header = tableViewRef.tableHeaderView else { return }
        let targetSize = CGSize(width: tableViewRef.bounds.width, height: UIView.layoutFittingCompressedSize.height)
        let height = header.systemLayoutSizeFitting(
            targetSize,
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height

        var frame = header.frame
        let needsHeightUpdate = frame.height != height
        let needsWidthUpdate = frame.width != tableViewRef.bounds.width
        if needsHeightUpdate || needsWidthUpdate {
            frame.size.height = height
            frame.size.width = tableViewRef.bounds.width
            header.frame = frame
            tableViewRef.tableHeaderView = header
        }
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
