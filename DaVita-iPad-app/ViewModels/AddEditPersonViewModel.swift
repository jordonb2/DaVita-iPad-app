import Foundation

/// ViewModel backing Add/Edit Person flow. Handles validation and draft creation.
final class AddEditPersonViewModel {

    struct Draft {
        let name: String
        let dob: Date
        let gender: Gender?
    }

    /// Existing record being edited, if any.
    private(set) var person: Person?

    /// Current input state.
    var name: String = ""
    var dob: Date = Date()
    var gender: Gender?

    init(person: Person? = nil) {
        self.person = person
        if let person {
            self.name = person.name ?? ""
            self.dob = person.dob ?? Date()
            self.gender = person.genderEnum
        }
    }

    var isEditingRecord: Bool { person != nil }

    /// Returns validation error message if invalid.
    func validate() -> String? {
        if InputSanitizer.personName(name) == nil {
            return "Please enter the patient's full name before saving."
        }
        if dob > Date() {
            return "Date of birth cannot be in the future."
        }
        return nil
    }

    func makeDraft() -> Draft {
        let sanitizedName = InputSanitizer.personName(name) ?? ""
        return Draft(name: sanitizedName, dob: dob, gender: gender)
    }

    func updateDOB(_ date: Date) {
        dob = date
    }

    func updateGender(from segmentIndex: Int) {
        gender = Gender.fromSegmentIndex(segmentIndex)
    }
}
