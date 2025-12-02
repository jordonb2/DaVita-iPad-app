//
//  AddEditPersonViewController.swift
//  DaVita-iPad-app
//
//  Created by Jordon Bowen on 10/4/25.
//

import UIKit

final class AddEditPersonViewController: UIViewController, UITextFieldDelegate {

    var router: AppRouting!
    
    private var viewModel = AddEditPersonViewModel()
    
    // MARK: - Outlets
    @IBOutlet weak var fullNameTextField: UITextField!
    @IBOutlet weak var datePicker: UIDatePicker!
    @IBOutlet weak var genderSegmentedControl: UISegmentedControl!
    @IBOutlet weak var ageLabel: UILabel!
    
    // MARK: - Callback to send data back
    /// Caller sets this to receive the new/edited person and update the list.
    var onSave: ((String, Date, Gender?, PersonCheckInData) -> Void)?
    
    // MARK: - Prefill (for editing)
    var personToEdit: Person? {
        didSet { viewModel = AddEditPersonViewModel(person: personToEdit) }
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        assert(router != nil, "AddEditPersonViewController.router must be injected before presentation")
        title = viewModel.isEditingRecord ? "Edit Person" : "Add Person"
        view.backgroundColor = .systemBackground
        configureUI()

        // Standardize modal navigation buttons (avoid relying on storyboard wiring).
        let cancel = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(cancelTapped(_:)))
        cancel.accessibilityLabel = "Cancel"
        cancel.accessibilityIdentifier = "addEdit.cancel"
        navigationItem.leftBarButtonItem = cancel

        let save = UIBarButtonItem(title: "Save", style: .done, target: self, action: #selector(saveTapped(_:)))
        save.accessibilityLabel = "Save"
        save.accessibilityIdentifier = "addEdit.save"
        navigationItem.rightBarButtonItem = save
        
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
        
        datePicker.maximumDate = ValidationRules.Person.maxDOBDate()
        fullNameTextField.delegate = self
        
        fullNameTextField.isAccessibilityElement = true
        fullNameTextField.accessibilityLabel = "Full name"
        fullNameTextField.accessibilityHint = "Enter the patient's full name."
        fullNameTextField.accessibilityIdentifier = "addEdit.fullName"
        
        datePicker.isAccessibilityElement = true
        datePicker.accessibilityLabel = "Date of birth"
        datePicker.accessibilityHint = "Select the patient's date of birth."
        datePicker.accessibilityIdentifier = "addEdit.dob"
        
        genderSegmentedControl.isAccessibilityElement = true
        genderSegmentedControl.accessibilityLabel = "Gender"
        genderSegmentedControl.accessibilityHint = "Select the patient's gender."
        genderSegmentedControl.accessibilityIdentifier = "addEdit.gender"
        
        ageLabel.isAccessibilityElement = true
        ageLabel.accessibilityTraits.insert(.staticText)
        
        accessibilityElements = [fullNameTextField as Any, datePicker as Any, genderSegmentedControl as Any, ageLabel as Any]
        // Prefill when editing
        fullNameTextField.text = viewModel.name
        datePicker.date = viewModel.dob
        updateAgeLabel(for: viewModel.dob)
        if let gender = viewModel.gender,
           let idx = Gender.allCases.firstIndex(of: gender) {
            genderSegmentedControl.selectedSegmentIndex = idx
        } else {
            genderSegmentedControl.selectedSegmentIndex = UISegmentedControl.noSegment
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
        if let years = DateDerived.ageYears(dob: date, now: now, calendar: calendar) {
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
        dismissModalFlow(animated: true)
    }
    
    @IBAction func saveTapped(_ sender: UIBarButtonItem) {
        viewModel.name = fullNameTextField.text ?? ""
        viewModel.updateDOB(datePicker.date)
        viewModel.updateGender(from: genderSegmentedControl.selectedSegmentIndex)
        
        if let errorMessage = viewModel.validate() {
            let alert = AlertFactory.okAlert(title: "Invalid input", message: errorMessage) { [weak self] in
                self?.fullNameTextField.becomeFirstResponder()
            }
            present(alert, animated: true)
            return
        }
        
        let draft = viewModel.makeDraft()
        
        router.presentCheckIn(from: self, onComplete: { [weak self] checkInData in
            guard let self else { return }
            self.onSave?(draft.name, draft.dob, draft.gender, checkInData)
            self.dismissModalFlow(animated: true)
        }, onSkip: { [weak self] in
            guard let self else { return }
            let emptyCheckIn = PersonCheckInData(painLevel: nil, energyBucket: nil, moodBucket: nil, symptoms: nil, concerns: nil, teamNote: nil)
            self.onSave?(draft.name, draft.dob, draft.gender, emptyCheckIn)
            self.dismissModalFlow(animated: true)
        })
    }

    // MARK: - UITextFieldDelegate

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        // Allow IME composition (marked text) without enforcing hard limits mid-composition.
        if textField.markedTextRange != nil { return true }

        guard textField === fullNameTextField else { return true }
        let current = textField.text ?? ""
        guard let r = Range(range, in: current) else { return true }
        let next = current.replacingCharacters(in: r, with: string)
        return next.count <= ValidationRules.Person.nameMaxChars
    }
}
