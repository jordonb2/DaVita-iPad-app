//
//  AddEditPersonViewController.swift
//  DaVita-iPad-app
//
//  Created by Jordon Bowen on 10/4/25.
//

import UIKit

final class AddEditPersonViewController: UIViewController {

    // MARK: - Outlets
    @IBOutlet weak var fullNameTextField: UITextField!
    @IBOutlet weak var datePicker: UIDatePicker!
    @IBOutlet weak var genderSegmentedControl: UISegmentedControl!

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Add/Edit Person"
        view.backgroundColor = .systemBackground
        configureUI()
    }

    private func configureUI() {
        // Optional: tweak date picker mode or segmented control here
        datePicker.datePickerMode = .date
    }

    // MARK: - Actions
    @IBAction func cancelTapped(_ sender: UIBarButtonItem) {
        dismiss(animated: true, completion: nil)
    }

    @IBAction func saveTapped(_ sender: UIBarButtonItem) {
        // Grab user-entered data
        let name = fullNameTextField.text ?? ""
        let dob = datePicker.date
        let genderIndex = genderSegmentedControl.selectedSegmentIndex
        let gender = genderSegmentedControl.titleForSegment(at: genderIndex) ?? ""

        print("Saving person: \(name), \(dob), \(gender)")

        // For now just dismiss (later we’ll save to Core Data)
        dismiss(animated: true, completion: nil)
    }
}
