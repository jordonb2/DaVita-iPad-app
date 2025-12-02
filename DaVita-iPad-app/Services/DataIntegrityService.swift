import Foundation
import CoreData

/// Performs lightweight Core Data integrity checks and repairs.
///
/// Transaction boundary:
/// - Runs on a background context and saves once if changes are needed.
///
/// Goals:
/// - Ensure required identity fields (`id`, `createdAt`) are present.
/// - Detect (and log) duplicate IDs where uniqueness is expected.
final class DataIntegrityService {
    private let coreDataStack: CoreDataStacking

    init(coreDataStack: CoreDataStacking) {
        self.coreDataStack = coreDataStack
    }

    func runInBackground() {
        let ctx = coreDataStack.newBackgroundContext()
        ctx.perform { [weak self] in
            guard let self else { return }
            do {
                try self.repairMissingRequiredFields(in: ctx)
                try self.reconcileDenormalizedLatestCheckInFields(in: ctx)
                try self.logDuplicateIDsIfAny(in: ctx)

                if ctx.hasChanges {
                    try ctx.save()
                }
            } catch {
                AppLog.persistence.error("Data integrity check failed: \(error, privacy: .public)")
            }
        }
    }

    // MARK: - Repairs

    private func repairMissingRequiredFields(in ctx: NSManagedObjectContext) throws {
        try repair(entityName: "Person", in: ctx)
        try repair(entityName: "CheckInRecord", in: ctx)
        try repair(entityName: "CheckInAnalyticsEvent", in: ctx)
    }

    private func repair(entityName: String, in ctx: NSManagedObjectContext) throws {
        let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
        request.fetchBatchSize = 200
        request.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [
            NSPredicate(format: "id == nil"),
            NSPredicate(format: "createdAt == nil")
        ])

        let objects = try ctx.fetch(request)
        guard !objects.isEmpty else { return }

        for obj in objects {
            if obj.value(forKey: "id") == nil {
                obj.setValue(UUID(), forKey: "id")
            }
            if obj.value(forKey: "createdAt") == nil {
                obj.setValue(Date(), forKey: "createdAt")
            }
        }

        AppLog.persistence.warning("Repaired missing required fields for \(objects.count, privacy: .public) \(entityName, privacy: .public) object(s)")
    }

    // MARK: - Denormalized "latest" reconciliation

    /// Ensures `Person`'s denormalized "latest check-in" fields match the newest `CheckInRecord`.
    ///
    /// Single source of truth: `CheckInRecord` history.
    private func reconcileDenormalizedLatestCheckInFields(in ctx: NSManagedObjectContext) throws {
        let peopleReq: NSFetchRequest<Person> = Person.fetchRequest()
        peopleReq.fetchBatchSize = 100

        let people = try ctx.fetch(peopleReq)
        guard !people.isEmpty else { return }

        var changed = 0
        for person in people {
            if try reconcileLatestCheckInFields(for: person, in: ctx) {
                changed += 1
            }
        }

        if changed > 0 {
            AppLog.persistence.warning("Reconciled latest check-in fields for \(changed, privacy: .public) person(s)")
        }
    }

    /// - Returns: true if any fields were modified.
    private func reconcileLatestCheckInFields(for person: Person, in ctx: NSManagedObjectContext) throws -> Bool {
        let req: NSFetchRequest<CheckInRecord> = CheckInRecord.fetchRequest()
        req.predicate = NSPredicate(format: "person == %@", person)
        req.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        req.fetchLimit = 1

        let latest = try ctx.fetch(req).first

        // No records: clear denormalized fields.
        guard let latest else {
            var didChange = false
            if person.checkInPain != 0 {
                person.checkInPain = 0
                didChange = true
            }
            if person.checkInEnergy != nil { person.checkInEnergy = nil; didChange = true }
            if person.checkInMood != nil { person.checkInMood = nil; didChange = true }
            if person.checkInSymptoms != nil { person.checkInSymptoms = nil; didChange = true }
            if person.checkInConcerns != nil { person.checkInConcerns = nil; didChange = true }
            if person.checkInTeamNote != nil { person.checkInTeamNote = nil; didChange = true }
            if person.value(forKey: "checkInEnergyBucket") != nil { person.setValue(nil, forKey: "checkInEnergyBucket"); didChange = true }
            if person.value(forKey: "checkInMoodBucket") != nil { person.setValue(nil, forKey: "checkInMoodBucket"); didChange = true }
            return didChange
        }

        var didChange = false

        // Pain
        if person.checkInPain != latest.painLevel {
            person.checkInPain = latest.painLevel
            didChange = true
        }

        // Energy bucket + display text
        let energyBucketN = latest.value(forKey: "energyBucket") as? NSNumber
        let energyBucket = energyBucketN.map { EnergyBucket(rawValue: $0.int16Value) } ?? nil
        let existingEnergyBucket = (person.value(forKey: "checkInEnergyBucket") as? NSNumber)?.int16Value
        let newEnergyBucketRaw = energyBucket?.rawValue
        if existingEnergyBucket != newEnergyBucketRaw {
            person.setValue(newEnergyBucketRaw, forKey: "checkInEnergyBucket")
            didChange = true
        }
        let newEnergyText = energyBucket?.displayText ?? latest.energyLevel
        if person.checkInEnergy != newEnergyText {
            person.checkInEnergy = newEnergyText
            didChange = true
        }

        // Mood bucket + display text
        let moodBucketN = latest.value(forKey: "moodBucket") as? NSNumber
        let moodBucket = moodBucketN.map { MoodBucket(rawValue: $0.int16Value) } ?? nil
        let existingMoodBucket = (person.value(forKey: "checkInMoodBucket") as? NSNumber)?.int16Value
        let newMoodBucketRaw = moodBucket?.rawValue
        if existingMoodBucket != newMoodBucketRaw {
            person.setValue(newMoodBucketRaw, forKey: "checkInMoodBucket")
            didChange = true
        }
        let newMoodText = moodBucket?.displayText ?? latest.mood
        if person.checkInMood != newMoodText {
            person.checkInMood = newMoodText
            didChange = true
        }

        // Notes
        if person.checkInSymptoms != latest.symptoms {
            person.checkInSymptoms = latest.symptoms
            didChange = true
        }
        if person.checkInConcerns != latest.concerns {
            person.checkInConcerns = latest.concerns
            didChange = true
        }
        if person.checkInTeamNote != latest.teamNote {
            person.checkInTeamNote = latest.teamNote
            didChange = true
        }

        return didChange
    }

    // MARK: - Duplicate detection

    private func logDuplicateIDsIfAny(in ctx: NSManagedObjectContext) throws {
        try logDuplicateIDs(entityName: "Person", in: ctx)
        try logDuplicateIDs(entityName: "CheckInRecord", in: ctx)
        try logDuplicateIDs(entityName: "CheckInAnalyticsEvent", in: ctx)
    }

    private func logDuplicateIDs(entityName: String, in ctx: NSManagedObjectContext) throws {
        // Group by id and count occurrences; log any ids with count > 1.
        let request = NSFetchRequest<NSDictionary>(entityName: entityName)
        request.resultType = .dictionaryResultType
        request.fetchBatchSize = 200
        request.propertiesToGroupBy = ["id"]

        let countDesc = NSExpressionDescription()
        countDesc.name = "count"
        countDesc.expression = NSExpression(forFunction: "count:", arguments: [NSExpression(forKeyPath: "id")])
        countDesc.expressionResultType = .integer64AttributeType

        request.propertiesToFetch = ["id", countDesc]
        request.havingPredicate = NSPredicate(format: "count > 1")

        let rows = try ctx.fetch(request)
        guard !rows.isEmpty else { return }

        AppLog.persistence.error("Detected duplicate IDs in \(entityName, privacy: .public): \(rows.count, privacy: .public) duplicate group(s)")
    }
}


