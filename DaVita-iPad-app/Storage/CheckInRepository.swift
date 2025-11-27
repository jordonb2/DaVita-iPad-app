import Foundation
import CoreData

/// Pure persistence layer for `CheckInRecord`.
final class CheckInRepository {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    // MARK: - Creates

    @discardableResult
    func createRecord(for person: Person, data: PersonCheckInData, at date: Date = Date()) -> CheckInRecord {
        let record = CheckInRecord(context: context)
        record.id = UUID()
        record.createdAt = date
        record.painLevel = data.painLevel ?? 0

        // Canonical buckets (preferred)
        if let b = data.energyBucket {
            record.setValue(b.rawValue, forKey: "energyBucket")
        } else {
            record.setValue(nil, forKey: "energyBucket")
        }
        if let b = data.moodBucket {
            record.setValue(b.rawValue, forKey: "moodBucket")
        } else {
            record.setValue(nil, forKey: "moodBucket")
        }

        // Keep legacy string fields populated with canonical text to avoid drift + preserve UI.
        record.energyLevel = data.energyLevelText
        record.mood = data.moodText

        record.symptoms = data.symptoms
        record.concerns = data.concerns
        record.teamNote = data.teamNote
        record.person = person
        return record
    }

    // MARK: - Fetches

    /// Fetch full check-in history for a person, newest first.
    func fetchHistory(for person: Person, limit: Int? = nil) throws -> [CheckInRecord] {
        let personInContext = try resolve(person: person)
        return try fetchHistory(forResolvedPerson: personInContext, limit: limit)
    }

    /// Fetch full check-in history for a person by `objectID`, newest first.
    func fetchHistory(personID: NSManagedObjectID, limit: Int? = nil) throws -> [CheckInRecord] {
        guard let person = try context.existingObject(with: personID) as? Person else {
            throw NSError(domain: "CheckInRepository", code: 1, userInfo: [NSLocalizedDescriptionKey: "Person not found for objectID"]) 
        }
        return try fetchHistory(forResolvedPerson: person, limit: limit)
    }

    /// Fetch the most recent check-in for a person.
    func fetchMostRecent(for person: Person) throws -> CheckInRecord? {
        try fetchHistory(for: person, limit: 1).first
    }

    /// Fetch the last N check-ins for a person.
    func fetchLastVisits(for person: Person, limit: Int) throws -> [CheckInRecord] {
        try fetchHistory(for: person, limit: limit)
    }

    /// Fetch the last N check-ins across all people (newest first).
    func fetchLastVisits(limit: Int) throws -> [CheckInRecord] {
        let request: NSFetchRequest<CheckInRecord> = CheckInRecord.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        request.fetchLimit = max(0, limit)
        return try context.fetch(request)
    }

    // MARK: - Private

    private func resolve(person: Person) throws -> Person {
        if person.managedObjectContext === context {
            return person
        }
        guard let resolved = try context.existingObject(with: person.objectID) as? Person else {
            throw NSError(domain: "CheckInRepository", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to resolve Person into repository context"]) 
        }
        return resolved
    }

    private func fetchHistory(forResolvedPerson person: Person, limit: Int?) throws -> [CheckInRecord] {
        let request: NSFetchRequest<CheckInRecord> = CheckInRecord.fetchRequest()
        request.predicate = NSPredicate(format: "person == %@", person)
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        if let limit {
            request.fetchLimit = max(0, limit)
        }
        return try context.fetch(request)
    }
}
