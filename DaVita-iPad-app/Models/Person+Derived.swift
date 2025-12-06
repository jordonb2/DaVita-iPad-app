import Foundation
import CoreData

extension Person {
    struct DOBAndAgeDisplay {
        let secondaryText: String
        let accessibilityLabel: String
    }

    /// Lowercased, sanitized name used for indexed sorting.
    var nameLowercasedValue: String? {
        get { value(forKey: "nameLowercased") as? String }
        set { setValue(newValue, forKey: "nameLowercased") }
    }

    /// Normalizes the given raw name to a lowercased, single-line token for sorting.
    static func normalizedLowercasedName(from raw: String?) -> String? {
        guard let sanitized = InputSanitizer.personName(raw) else { return nil }
        return sanitized.lowercased()
    }

    /// Cached DOB+Age display strings for list rendering.
    ///
    /// Cache key includes:
    /// - person objectID URI
    /// - dob timestamp (so edits invalidate)
    /// - day start timestamp (so it updates across day boundaries)
    func dobAndAgeDisplay(now: Date = Date(), calendar: Calendar = .current) -> DOBAndAgeDisplay? {
        guard let dob else { return nil }

        let dayStart = calendar.startOfDay(for: now).timeIntervalSince1970
        let dobTS = dob.timeIntervalSince1970
        let key = "\(objectID.uriRepresentation().absoluteString)|\(dobTS)|\(dayStart)" as NSString

        if let cached = PersonDerivedCache.ageCache.object(forKey: key) {
            return cached.value
        }

        let dobString = PersonDerivedCache.dobFormatter.string(from: dob)
        let age = DateDerived.ageYears(dob: dob, now: now, calendar: calendar) ?? 0

        let nameText = name ?? ""
        let value = DOBAndAgeDisplay(
            secondaryText: "DOB: \(dobString) — Age: \(age)",
            accessibilityLabel: "\(nameText). Date of birth \(dobString). Age \(age)."
        )
        PersonDerivedCache.ageCache.setObject(PersonDerivedCache.Box(value), forKey: key)
        return value
    }

    /// "Latest check-in" snapshot derived from denormalized `Person.checkIn*` fields.
    ///
    /// Note: The single source of truth for history is `CheckInRecord`; these are a cached view.
    var latestCheckInSnapshot: PersonCheckInData {
        let energyBucket: EnergyBucket? = {
            if let n = value(forKey: "checkInEnergyBucket") as? NSNumber {
                return EnergyBucket(rawValue: n.int16Value)
            }
            return nil
        }()

        let moodBucket: MoodBucket? = {
            if let n = value(forKey: "checkInMoodBucket") as? NSNumber {
                return MoodBucket(rawValue: n.int16Value)
            }
            return nil
        }()

        let pain: Int16? = {
            // If no check-ins exist pain is reconciled to 0; treat 0 as nil for snapshot.
            let p = checkInPain
            return p == 0 ? nil : p
        }()

        return PersonCheckInData(
            painLevel: pain,
            energyBucket: energyBucket,
            moodBucket: moodBucket,
            symptoms: checkInSymptoms,
            concerns: checkInConcerns,
            teamNote: checkInTeamNote
        )
    }
}

private enum PersonDerivedCache {
    final class Box<T>: NSObject {
        let value: T
        init(_ value: T) { self.value = value }
    }

    static let ageCache: NSCache<NSString, Box<Person.DOBAndAgeDisplay>> = {
        let c = NSCache<NSString, Box<Person.DOBAndAgeDisplay>>()
        c.countLimit = 2_000
        return c
    }()

    static let dobFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()
}


