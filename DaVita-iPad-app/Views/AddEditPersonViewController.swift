//
//  AddEditPersonViewController.swift
//  DaVita-iPad-app
//
//  Created by Jordon Bowen on 10/4/25.
//

import UIKit

final class AddEditPersonViewController: UIViewController {
    
    private var viewModel = AddEditPersonViewModel()
    
    // MARK: - Outlets
    @IBOutlet weak var fullNameTextField: UITextField!
    @IBOutlet weak var datePicker: UIDatePicker!
    @IBOutlet weak var genderSegmentedControl: UISegmentedControl!
    @IBOutlet weak var ageLabel: UILabel!
    
    // MARK: - Callback to send data back
    /// Caller sets this to receive the new/edited person and update the list.
    var onSave: ((String, Date, String, PersonCheckInData) -> Void)?
    
    // MARK: - Prefill (for editing)
    var personToEdit: Person? {
        didSet { viewModel = AddEditPersonViewModel(person: personToEdit) }
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        title = viewModel.isEditingRecord ? "Edit Person" : "Add/Edit Person"
        view.backgroundColor = .systemBackground
        configureUI()
        
        fullNameTextField.font = UIFont.preferredFont(forTextStyle: .body)
        fullNameTextField.adjustsFontForContentSizeCategory = true
        fullNameTextField.textColor = .label
        
        ageLabel.font = UIFont.preferredFont(forTextStyle: .headline)
        ageLabel.adjustsFontForContentSizeCategory = true
        ageLabel.textColor = .label
        
        let bodyFont = UIFont.preferredFont(forTextStyle: .body)
        let scaledBodyFont = UIFontMetrics(forTextStyle: .body).scaledFont(for: bodyFont)
        let normalAttributes: [NSAttributedString.Key: Any] = [.font: scaledBodyFont]
        genderSegmentedControl.setTitleTextAttributes(normalAttributes, for: .normal)
        genderSegmentedControl.setTitleTextAttributes(normalAttributes, for: .selected)
        
        datePicker.maximumDate = Date()
        
        fullNameTextField.isAccessibilityElement = true
        fullNameTextField.accessibilityLabel = "Full name"
        fullNameTextField.accessibilityHint = "Enter the patient's full name."
        
        datePicker.isAccessibilityElement = true
        datePicker.accessibilityLabel = "Date of birth"
        datePicker.accessibilityHint = "Select the patient's date of birth."
        
        genderSegmentedControl.isAccessibilityElement = true
        genderSegmentedControl.accessibilityLabel = "Gender"
        genderSegmentedControl.accessibilityHint = "Select the patient's gender."
        
        ageLabel.isAccessibilityElement = true
        ageLabel.accessibilityTraits.insert(.staticText)
        
        navigationItem.leftBarButtonItem?.accessibilityLabel = "Cancel"
        navigationItem.rightBarButtonItem?.accessibilityLabel = "Save"
        
        accessibilityElements = [fullNameTextField as Any, datePicker as Any, genderSegmentedControl as Any, ageLabel as Any]
        // Prefill when editing
        fullNameTextField.text = viewModel.name
        datePicker.date = viewModel.dob
        updateAgeLabel(for: viewModel.dob)
        if !viewModel.gender.isEmpty {
            let map = ["Male", "Female", "Other"]
            if let idx = map.firstIndex(of: viewModel.gender) {
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
        viewModel.updateDOB(sender.date)
        updateAgeLabel(for: sender.date)
    }
    
    // Calculate and update age
    private func updateAgeLabel(for date: Date) {
        let calendar = Calendar.current
        let now = Date()
        let ageComponents = calendar.dateComponents([.year], from: date, to: now)
        if let years = ageComponents.year {
            ageLabel.text = "Age: \(years)"
            ageLabel.accessibilityLabel = "Age"
            ageLabel.accessibilityValue = "\(years)"
        } else {
            ageLabel.text = "Age: -"
            ageLabel.accessibilityLabel = "Age"
            ageLabel.accessibilityValue = "Not available"
        }
    }
    
    // MARK: - Actions
    @IBAction func cancelTapped(_ sender: UIBarButtonItem) {
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func saveTapped(_ sender: UIBarButtonItem) {
        viewModel.name = fullNameTextField.text ?? ""
        viewModel.updateDOB(datePicker.date)
        let genderTitles = ["Male", "Female", "Other"]
        viewModel.updateGender(from: genderSegmentedControl.selectedSegmentIndex, titles: genderTitles)
        
        if let errorMessage = viewModel.validate() {
            let alert = UIAlertController(title: "Invalid input", message: errorMessage, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
                self?.fullNameTextField.becomeFirstResponder()
            })
            present(alert, animated: true)
            return
        }
        
        let draft = viewModel.makeDraft()
        
        let checkInVC = CheckInJourneyViewController()
        checkInVC.onComplete = { [weak self] checkInData in
            guard let self else { return }
            self.onSave?(draft.name, draft.dob, draft.gender, checkInData)
            self.dismiss(animated: true) { [weak self] in
                self?.dismiss(animated: true, completion: nil)
            }
        }
        checkInVC.onSkip = { [weak self] in
            guard let self else { return }
            let emptyCheckIn = PersonCheckInData(painLevel: nil, energyLevel: nil, mood: nil, symptoms: nil, concerns: nil, teamNote: nil)
            self.onSave?(draft.name, draft.dob, draft.gender, emptyCheckIn)
            self.dismiss(animated: true) { [weak self] in
                self?.dismiss(animated: true, completion: nil)
            }
        }
        
        let nav = UINavigationController(rootViewController: checkInVC)
        nav.modalPresentationStyle = .formSheet
        present(nav, animated: true)
    }
}
