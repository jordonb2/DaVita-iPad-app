import Foundation
import CoreData

/// Typed filter for check-in history queries.
struct CheckInHistoryFilter {
    /// Inclusive start date (>=). Nil = no lower bound.
    var startDate: Date?

    /// Inclusive end date (<=). Nil = no upper bound.
    var endDate: Date?

    /// Symptom/concern keyword (case/diacritic-insensitive). Nil/empty = no keyword filter.
    var keyword: String?

    /// Maximum number of records (newest first). Nil = no limit.
    var limit: Int?

    init(startDate: Date? = nil, endDate: Date? = nil, keyword: String? = nil, limit: Int? = nil) {
        self.startDate = startDate
        self.endDate = endDate
        self.keyword = keyword
        self.limit = limit
    }

    var normalizedKeyword: String? {
        guard let keyword = keyword?.trimmingCharacters(in: .whitespacesAndNewlines), !keyword.isEmpty else { return nil }
        return keyword
    }
}

/// Pure persistence layer for `CheckInRecord`.
final class CheckInRepository {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    // MARK: - Creates

    @discardableResult
    func createRecord(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        for person: Person,
        data: PersonCheckInData
    ) -> CheckInRecord {
        let sanitized = data.sanitized()
        let record = CheckInRecord(context: context)
        // Enforce non-optional identity + timestamps at creation time.
        record.id = id
        record.createdAt = createdAt
        record.painLevel = sanitized.painLevel ?? 0

        // Canonical buckets (preferred)
        if let b = sanitized.energyBucket {
            record.setValue(b.rawValue, forKey: "energyBucket")
        } else {
            record.setValue(nil, forKey: "energyBucket")
        }
        if let b = sanitized.moodBucket {
            record.setValue(b.rawValue, forKey: "moodBucket")
        } else {
            record.setValue(nil, forKey: "moodBucket")
        }

        // Keep legacy string fields populated with canonical text to avoid drift + preserve UI.
        record.energyLevel = sanitized.energyLevelText
        record.mood = sanitized.moodText

        record.symptoms = sanitized.symptoms
        record.concerns = sanitized.concerns
        record.teamNote = sanitized.teamNote
        record.person = person
        return record
    }

    // MARK: - Fetches

    /// Fetch full check-in history for a person, newest first.
    func fetchHistory(for person: Person, limit: Int? = nil) throws -> [CheckInRecord] {
        try fetchHistory(for: person, filter: CheckInHistoryFilter(limit: limit))
    }

    /// Fetch full check-in history for a person with filters, newest first.
    func fetchHistory(for person: Person, filter: CheckInHistoryFilter) throws -> [CheckInRecord] {
        let personInContext = try resolve(person: person)
        return try fetchHistory(forResolvedPerson: personInContext, filter: filter)
    }

    /// Fetch full check-in history for a person by `objectID`, newest first.
    func fetchHistory(personID: NSManagedObjectID, limit: Int? = nil) throws -> [CheckInRecord] {
        try fetchHistory(personID: personID, filter: CheckInHistoryFilter(limit: limit))
    }

    /// Fetch full check-in history for a person by `objectID` with filters, newest first.
    func fetchHistory(personID: NSManagedObjectID, filter: CheckInHistoryFilter) throws -> [CheckInRecord] {
        guard let person = try context.existingObject(with: personID) as? Person else {
            throw NSError(domain: "CheckInRepository", code: 1, userInfo: [NSLocalizedDescriptionKey: "Person not found for objectID"])
        }
        return try fetchHistory(forResolvedPerson: person, filter: filter)
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
        try fetchVisits(filter: CheckInHistoryFilter(limit: limit))
    }

    /// Fetch check-in records across all people with filters (newest first).
    func fetchVisits(filter: CheckInHistoryFilter) throws -> [CheckInRecord] {
        let request: NSFetchRequest<CheckInRecord> = CheckInRecord.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        request.predicate = predicate(for: filter, person: nil)
        if let limit = filter.limit {
            request.fetchLimit = max(0, limit)
        }
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

    private func fetchHistory(forResolvedPerson person: Person, filter: CheckInHistoryFilter) throws -> [CheckInRecord] {
        let request: NSFetchRequest<CheckInRecord> = CheckInRecord.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        request.predicate = predicate(for: filter, person: person)
        if let limit = filter.limit {
            request.fetchLimit = max(0, limit)
        }
        return try context.fetch(request)
    }

    private func predicate(for filter: CheckInHistoryFilter, person: Person?) -> NSPredicate? {
        var predicates: [NSPredicate] = []

        if let person {
            predicates.append(NSPredicate(format: "person == %@", person))
        }

        if let start = filter.startDate {
            predicates.append(NSPredicate(format: "createdAt >= %@", start as NSDate))
        }

        if let end = filter.endDate {
            predicates.append(NSPredicate(format: "createdAt <= %@", end as NSDate))
        }

        if let keyword = filter.normalizedKeyword {
            // Search symptoms OR concerns (case/diacritic-insensitive)
            let s = NSPredicate(format: "symptoms CONTAINS[cd] %@", keyword)
            let c = NSPredicate(format: "concerns CONTAINS[cd] %@", keyword)
            predicates.append(NSCompoundPredicate(orPredicateWithSubpredicates: [s, c]))
        }

        guard !predicates.isEmpty else { return nil }
        return NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }
}
