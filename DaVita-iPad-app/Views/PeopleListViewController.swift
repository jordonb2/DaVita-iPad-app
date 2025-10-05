//
//  PeopleListViewController.swift
//  DaVita-iPad-app
//
//  Created by Jordon Bowen on 10/3/25.
//

import UIKit
import Combine

final class PeopleListViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    // If your table view is the ROOT view, we can grab it like this:
    private var tableViewRef: UITableView { self.view as! UITableView }
    
    private let viewModel = PeopleListViewModel()
    private var cancellables = Set<AnyCancellable>()
    
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
        
        let tableView = tableViewRef
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        
        // Subscribe to Combine publisher to auto-reload on DB changes
        viewModel.$people
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.tableViewRef.reloadData()
            }
            .store(in: &cancellables)
    }
    
    @objc private func didTapAdd() {
        // 1) Instantiate the Add/Edit screen from Main.storyboard
        let sb = UIStoryboard(name: "Main", bundle: nil)
        guard let addVC = sb.instantiateViewController(
            withIdentifier: "AddEditPersonVC"
        ) as? AddEditPersonViewController else {
            return
        }
        
        // 2) Handle Save -> push into your view model
        addVC.onSave = { [weak self] name, dob, gender in
            // TODO: adjust this to match your VM’s API
            // Example options:
            // self?.viewModel.add(name: name, dob: dob, gender: gender)
            self?.viewModel.add(name: name) // if your VM currently only takes name
        }
        
        // 3) Present inside a nav so the Cancel/Save live in a bar
        let nav = UINavigationController(rootViewController: addVC)
        nav.modalPresentationStyle = .fullScreen
        nav.modalTransitionStyle = .coverVertical
        present(nav, animated: true)
    }
    
    // MARK: - UITableViewDataSource
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.count
    }
    
    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let person = viewModel.person(at: indexPath)
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        var config = cell.defaultContentConfiguration()
        config.text = person.name
        if let dob = person.dob {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            config.secondaryText = "DOB: " + formatter.string(from: dob)
        } else {
            config.secondaryText = nil
        }
        cell.contentConfiguration = config
        return cell
    }
    
    // MARK: - UITableViewDelegate (swipe to delete)
    func tableView(_ tableView: UITableView,
                   trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath)
    -> UISwipeActionsConfiguration? {
        let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _,_,done in
            guard let self else { return }
            let person = self.viewModel.person(at: indexPath)
            self.viewModel.delete(person)
            done(true)
        }
        return UISwipeActionsConfiguration(actions: [deleteAction])
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        // TODO: navigate to Add/Edit form pre-populated with this person
        // let person = viewModel.person(at: indexPath)
    }
}
