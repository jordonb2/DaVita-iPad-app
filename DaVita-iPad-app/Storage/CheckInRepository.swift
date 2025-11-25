import Foundation
import CoreData

/// Pure persistence layer for CheckInRecord.
final class CheckInRepository {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    @discardableResult
    func createRecord(for person: Person, data: PersonCheckInData, at date: Date = Date()) -> CheckInRecord {
        let record = CheckInRecord(context: context)
        record.id = UUID()
        record.createdAt = date
        record.painLevel = data.painLevel ?? 0
        record.energyLevel = data.energyLevel
        record.mood = data.mood
        record.symptoms = data.symptoms
        record.concerns = data.concerns
        record.teamNote = data.teamNote
        record.person = person
        return record
    }
}
