import Foundation
import CoreData

/// Business logic layer for writing check-ins.
///
/// Centralizes:
/// - updating the "latest check-in" fields on `Person` (in the person's context)
/// - creating a `CheckInRecord` on a background context (to keep UI smooth)
final class CheckInService {
    private let coreDataStack: CoreDataStacking

    init(coreDataStack: CoreDataStacking) {
        self.coreDataStack = coreDataStack
    }

    func applyLatestCheckInFields(to person: Person, data: PersonCheckInData) {
        guard let context = person.managedObjectContext else {
            // Shouldn't happen in normal app flow; keep it non-fatal.
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
            return
        }

        context.performAndWait {
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

    /// Creates a new `CheckInRecord` on a background context and saves that background context.
    ///
    /// Important: the `Person` must already be saved to the persistent store so it can be resolved
    /// by `objectID` from the background context.
    func createCheckInRecord(for person: Person, data: PersonCheckInData, at date: Date = Date()) {
        let personID = person.objectID
        let bgContext = coreDataStack.newBackgroundContext()

        bgContext.perform {
            do {
                guard let bgPerson = try bgContext.existingObject(with: personID) as? Person else {
                    AppLog.persistence.error("CheckInService: failed to resolve Person in background context")
                    return
                }

                let repo = CheckInRepository(context: bgContext)
                let sanitized = data.sanitized()
                if data.needsSanitization() {
                    AppLog.persistence.warning("Sanitized check-in input before record creation")
                }
                _ = repo.createRecord(createdAt: date, for: bgPerson, data: sanitized)

                if bgContext.hasChanges {
                    try bgContext.save()
                }
            } catch {
                AppLog.persistence.error("CheckInService background save error: \(error, privacy: .public)")
            }
        }
    }

    /// Common write flow used by multiple screens:
    /// 1) update latest fields on the `Person` (in UI context)
    /// 2) caller saves their context (transaction boundary)
    /// 3) create the `CheckInRecord` on a background context
    func writeCheckIn(for person: Person,
                      data: PersonCheckInData,
                      at date: Date = Date(),
                      savingUsing save: () throws -> Void) rethrows {
        let sanitized = data.sanitized()
        if data.needsSanitization() {
            AppLog.persistence.warning("Sanitized check-in input before save")
        }
        applyLatestCheckInFields(to: person, data: sanitized)
        try save()
        createCheckInRecord(for: person, data: data, at: date)
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
            AppLog.persistence.error("CheckInService latest fetch error: \(error, privacy: .public)")
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
