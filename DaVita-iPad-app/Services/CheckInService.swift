import Foundation
import CoreData

protocol CheckInServicing {
    /// Transaction boundary: this method **owns the save** and always writes on a background context.
    func writeCheckIn(personID: NSManagedObjectID,
                      data: PersonCheckInData,
                      at date: Date) throws
}

/// Business logic layer for writing check-ins.
///
/// Centralizes:
/// - updating the "latest check-in" fields on `Person` (in the person's context)
/// - creating a `CheckInRecord` on a background context (to keep UI smooth)
final class CheckInService: CheckInServicing {
    private let coreDataStack: CoreDataStacking
    private let reminderHandler: SmartReminderHandling?
    private let escalationHandler: EscalationHandling?
    private let syncHandler: CheckInSyncHandling?

    init(coreDataStack: CoreDataStacking,
         reminderHandler: SmartReminderHandling? = nil,
         escalationHandler: EscalationHandling? = nil,
         syncHandler: CheckInSyncHandling? = nil) {
        self.coreDataStack = coreDataStack
        self.reminderHandler = reminderHandler
        self.escalationHandler = escalationHandler
        self.syncHandler = syncHandler
    }

    /// Writes a check-in by resolving `personID` into a background context, applying denormalized latest fields,
    /// inserting the `CheckInRecord`, and saving once (single transaction boundary).
    func writeCheckIn(personID: NSManagedObjectID,
                      data: PersonCheckInData,
                      at date: Date = Date()) throws {
        let sanitized = data.sanitized()
        if data.needsSanitization() {
            AppLog.persistence.warning("Sanitized check-in input before write")
        }

        try coreDataStack.performBackgroundTaskAndWait { ctx in
            guard let person = try ctx.existingObject(with: personID) as? Person else {
                AppLog.persistence.error("CheckInService: failed to resolve Person for objectID")
                return
            }

            applyLatestCheckInFields(to: person, data: sanitized)
            _ = CheckInRepository(context: ctx).createRecord(createdAt: date, for: person, data: sanitized)

            if ctx.hasChanges {
                try ctx.save()
            }
        }

        reminderHandler?.handleCheckIn(painLevel: sanitized.painLevel, at: date)
        escalationHandler?.handleCheckIn(personID: personID, data: sanitized, at: date)
        syncHandler?.enqueueForSync(personID: personID, createdAt: date, data: sanitized)
    }


    // MARK: - Derived latest check-in (from history)

    /// Fetches the most recent `CheckInRecord` for a person.
    ///
    /// This is the source of truth for "latest check-in". `Person` also stores denormalized latest fields
    /// for fast UI display; use `ensureLatestFieldsConsistent(for:)` to reconcile.
    func fetchLatestCheckInRecord(for person: Person) -> CheckInRecord? {
        guard let ctx = person.managedObjectContext else { return nil }
        let repo = CheckInRepository(context: ctx)
        do {
            return try repo.fetchMostRecent(for: person)
        } catch {
            AppLog.persistence.error("CheckInService latest fetch error: \(error, privacy: .private)")
            return nil
        }
    }

    /// Converts the most recent `CheckInRecord` into a `PersonCheckInData` snapshot.
    func latestCheckInDataDerived(for person: Person) -> PersonCheckInData? {
        guard let record = fetchLatestCheckInRecord(for: person) else { return nil }

        // Prefer buckets, fall back to legacy strings.
        let energyBucket: EnergyBucket? = {
            if let n = record.value(forKey: "energyBucket") as? NSNumber {
                return EnergyBucket(rawValue: n.int16Value)
            }
            return EnergyBucket.from(legacyText: record.energyLevel)
        }()

        let moodBucket: MoodBucket? = {
            if let n = record.value(forKey: "moodBucket") as? NSNumber {
                return MoodBucket(rawValue: n.int16Value)
            }
            return MoodBucket.from(legacyText: record.mood)
        }()

        return PersonCheckInData(
            painLevel: record.painLevel,
            energyBucket: energyBucket,
            moodBucket: moodBucket,
            symptoms: record.symptoms,
            concerns: record.concerns,
            teamNote: record.teamNote
        )
    }

    /// Keeps `Person`'s denormalized "latest check-in" fields consistent with the newest `CheckInRecord`.
    ///
    /// - Note: This does not save; callers control save boundaries.
    func ensureLatestFieldsConsistent(for person: Person) {
        guard let ctx = person.managedObjectContext else { return }

        ctx.performAndWait {
            guard let derived = latestCheckInDataDerived(for: person) else {
                // No records: clear latest fields.
                person.checkInPain = 0
                person.checkInEnergy = nil
                person.checkInMood = nil
                person.checkInSymptoms = nil
                person.checkInConcerns = nil
                person.checkInTeamNote = nil
                person.setValue(nil, forKey: "checkInEnergyBucket")
                person.setValue(nil, forKey: "checkInMoodBucket")
                return
            }

            // Re-apply the latest fields from derived history.
            applyLatestCheckInFields(to: person, data: derived)
        }
    }
}

private extension CheckInService {
    /// Assumes the caller is executing on `person`'s context queue.
    func applyLatestCheckInFields(to person: Person, data: PersonCheckInData) {
        person.checkInPain = data.painLevel ?? 0
        if let b = data.energyBucket {
            person.setValue(b.rawValue, forKey: "checkInEnergyBucket")
        } else {
            person.setValue(nil, forKey: "checkInEnergyBucket")
        }
        if let b = data.moodBucket {
            person.setValue(b.rawValue, forKey: "checkInMoodBucket")
        } else {
            person.setValue(nil, forKey: "checkInMoodBucket")
        }
        person.checkInEnergy = data.energyLevelText
        person.checkInMood = data.moodText
        person.checkInSymptoms = data.symptoms
        person.checkInConcerns = data.concerns
        person.checkInTeamNote = data.teamNote
    }
}
