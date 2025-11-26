import Foundation

/// Business logic layer for writing check-ins.
///
/// Centralizes:
/// - creating a `CheckInRecord`
/// - updating the "latest check-in" fields on `Person`
///
/// Note: This service does **not** save the Core Data context; callers control transaction boundaries.
final class CheckInService {
    private let checkInRepo: CheckInRepository

    init(checkInRepo: CheckInRepository) {
        self.checkInRepo = checkInRepo
    }

    func applyLatestCheckInFields(to person: Person, data: PersonCheckInData) {
        person.checkInPain = data.painLevel ?? 0
        person.checkInEnergy = data.energyLevel
        person.checkInMood = data.mood
        person.checkInSymptoms = data.symptoms
        person.checkInConcerns = data.concerns
        person.checkInTeamNote = data.teamNote
    }

    /// Creates a new `CheckInRecord` (but does not save).
    @discardableResult
    func createCheckInRecord(for person: Person, data: PersonCheckInData, at date: Date = Date()) -> CheckInRecord {
        checkInRepo.createRecord(for: person, data: data, at: date)
    }

    /// Convenience for the common write flow used by multiple screens:
    /// update latest fields + create a record (but does not save).
    @discardableResult
    func writeCheckIn(for person: Person, data: PersonCheckInData, at date: Date = Date()) -> CheckInRecord {
        applyLatestCheckInFields(to: person, data: data)
        return createCheckInRecord(for: person, data: data, at: date)
    }
}
