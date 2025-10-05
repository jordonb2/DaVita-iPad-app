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
    
    // MARK: - Callback to send data back
    /// Caller sets this to receive the new/edited person and update the list.
    var onSave: ((String, Date, String) -> Void)?

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
        // validate & collect
        let name = (fullNameTextField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            fullNameTextField.becomeFirstResponder()
            return
        }
        let dob = datePicker.date
        let genderIndex = genderSegmentedControl.selectedSegmentIndex
        let gender = genderSegmentedControl.titleForSegment(at: genderIndex) ?? ""
        
        // send back to the list VC
        onSave?(name, dob, gender)

        print("Saving person: \(name), \(dob), \(gender)")

        // For now just dismiss (later we’ll save to Core Data)
        dismiss(animated: true, completion: nil)
    }
}
