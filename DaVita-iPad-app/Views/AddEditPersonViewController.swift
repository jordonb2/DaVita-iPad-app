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
    @IBOutlet weak var ageLabel: UILabel!
    
    // MARK: - Callback to send data back
    /// Caller sets this to receive the new/edited person and update the list.
    var onSave: ((String, Date, String) -> Void)?
    
    // MARK: - Prefill (for editing)
    var initialName: String?
    var initialDOB: Date?
    var initialGender: String?   // "Male" | "Female" | "Other"
    var isEditingRecord: Bool { initialName != nil }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        title = isEditingRecord ? "Edit Person" : "Add/Edit Person"
        view.backgroundColor = .systemBackground
        configureUI()
        
        // Prefill when editing
        if let name = initialName {
            fullNameTextField.text = name
        }
        if let dob = initialDOB {
            datePicker.date = dob
            updateAgeLabel(for: dob)   // keep age label in sync
        }
        if let g = initialGender {
            let map = ["Male", "Female", "Other"]
            if let idx = map.firstIndex(of: g) {
                genderSegmentedControl.selectedSegmentIndex = idx
            }
        }
    }

    private func configureUI() {
        // Optional: tweak date picker mode or segmented control here
        datePicker.datePickerMode = .date
        datePicker.addTarget(self, action: #selector(dateChanged(_:)), for: .valueChanged)
        updateAgeLabel(for: datePicker.date)
    }

    // Handle picker changes
    @objc private func dateChanged(_ sender: UIDatePicker) {
        updateAgeLabel(for: sender.date)
    }

    // Calculate and update age
    private func updateAgeLabel(for date: Date) {
        let calendar = Calendar.current
        let now = Date()
        let ageComponents = calendar.dateComponents([.year], from: date, to: now)
        if let years = ageComponents.year {
            ageLabel.text = "Age: \(years)"
        } else {
            ageLabel.text = "Age: -"
        }
    }

    // MARK: - Actions
    @IBAction func cancelTapped(_ sender: UIBarButtonItem) {
        dismiss(animated: true, completion: nil)
    }

    @IBAction func saveTapped(_ sender: UIBarButtonItem) {
        // Validate & collect
        let rawName = fullNameTextField.text ?? ""
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Require a non-empty name
        guard !name.isEmpty else {
            let alert = UIAlertController(
                title: "Name required",
                message: "Please enter the patient's full name before saving.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
                self?.fullNameTextField.becomeFirstResponder()
            })
            present(alert, animated: true)
            return
        }
        
        let dob = datePicker.date
        
        // Optional: prevent future dates of birth
        if dob > Date() {
            let alert = UIAlertController(
                title: "Invalid date",
                message: "Date of birth cannot be in the future.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            present(alert, animated: true)
            return
        }
        
        let genderIndex = genderSegmentedControl.selectedSegmentIndex
        let gender = genderSegmentedControl.titleForSegment(at: genderIndex) ?? ""
        
        // Send back to the list VC
        onSave?(name, dob, gender)
        
        // Dismiss once saved
        dismiss(animated: true, completion: nil)
    }
}
