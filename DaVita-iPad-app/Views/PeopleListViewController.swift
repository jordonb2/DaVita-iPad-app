//
//  PeopleListViewController.swift
//  DaVita-iPad-app
//
//  Created by Jordon Bowen on 10/3/25.
//

import UIKit

class PeopleListViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    // Temporary test data
    var people = ["Alice", "Bob", "Charlie"]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "People List"
        view.backgroundColor = .systemBackground

        let addButton = UIBarButtonItem(barButtonSystemItem: .add,
                                        target: self,
                                        action: #selector(didTapAdd))
        navigationItem.rightBarButtonItem = addButton

        // If your table is the root view:
        let tableView = self.view as! UITableView
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
    }

    @objc private func didTapAdd() {
        print("Add tapped")
    }
    
    // MARK: - UITableViewDataSource
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return people.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.textLabel?.text = people[indexPath.row]
        return cell
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
