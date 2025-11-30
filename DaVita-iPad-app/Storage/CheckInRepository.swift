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

    /// Fetch offset for paging (newest first). Nil/0 = no offset.
    var offset: Int?

    init(startDate: Date? = nil, endDate: Date? = nil, keyword: String? = nil, limit: Int? = nil, offset: Int? = nil) {
        self.startDate = startDate
        self.endDate = endDate
        self.keyword = keyword
        self.limit = limit
        self.offset = offset
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

    func makeHistoryFRC(person: Person? = nil,
                        filter: CheckInHistoryFilter = CheckInHistoryFilter(),
                        delegate: NSFetchedResultsControllerDelegate?) throws -> NSFetchedResultsController<CheckInRecord> {
        let request: NSFetchRequest<CheckInRecord> = CheckInRecord.fetchRequest()

        // Sort by person then createdAt desc so sections are stable.
        if person == nil {
            request.sortDescriptors = [
                NSSortDescriptor(key: "person.name", ascending: true),
                NSSortDescriptor(key: "createdAt", ascending: false)
            ]
        } else {
            request.sortDescriptors = [
                NSSortDescriptor(key: "createdAt", ascending: false)
            ]
        }

        // Predicate using the same filter logic.
        let resolvedPerson: Person?
        if let person {
            resolvedPerson = try resolve(person: person)
        } else {
            resolvedPerson = nil
        }
        request.predicate = predicate(for: filter, person: resolvedPerson)

        // Fetch in batches for memory efficiency.
        request.fetchBatchSize = 50

        let sectionKeyPath: String? = (person == nil) ? "person.name" : nil
        let frc = NSFetchedResultsController(
            fetchRequest: request,
            managedObjectContext: context,
            sectionNameKeyPath: sectionKeyPath,
            cacheName: nil
        )
        frc.delegate = delegate
        try frc.performFetch()
        return frc
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


    /// Fetch a page of check-in history for a person.
    ///
    /// - Returns: (records, hasMore)
    func fetchHistoryPage(for person: Person, filter: CheckInHistoryFilter) throws -> ([CheckInRecord], Bool) {
        // Fetch one extra to detect if more exists.
        var f = filter
        let pageSize = f.limit
        if let pageSize {
            f.limit = pageSize + 1
        }

        let records = try fetchHistory(for: person, filter: f)
        guard let pageSize else {
            return (records, false)
        }

        if records.count > pageSize {
            return (Array(records.prefix(pageSize)), true)
        }
        return (records, false)
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
        if let offset = filter.offset, offset > 0 {
            request.fetchOffset = offset
        }
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
        if let offset = filter.offset, offset > 0 {
            request.fetchOffset = offset
        }
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
