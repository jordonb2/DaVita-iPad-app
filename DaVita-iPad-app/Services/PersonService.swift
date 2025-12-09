import Foundation
import CoreData

protocol PersonServicing {
    func addPerson(name: String, gender: Gender?, dob: Date?, checkInData: PersonCheckInData?) throws

    func updatePerson(personID: NSManagedObjectID, name: String, gender: Gender?, dob: Date?, checkInData: PersonCheckInData?) throws
    func deletePerson(personID: NSManagedObjectID) throws
}

/// Business logic layer for people + visit history.
final class PersonService: PersonServicing {
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

    func addPerson(name: String, gender: Gender?, dob: Date?, checkInData: PersonCheckInData?) throws {
        let name = InputSanitizer.personName(name) ?? ""
        var personID: NSManagedObjectID?
        var sanitizedCheckIn: PersonCheckInData?
        let checkInDate = Date()

        try coreDataStack.performBackgroundTaskAndWait { ctx in
            let peopleRepo = PersonRepository(context: ctx)
            let person = peopleRepo.createPerson(name: name, gender: gender, dob: dob)
            personID = person.objectID

            if let checkInData {
                let sanitized = checkInData.sanitized()
                let merged = sanitized.mergedForPersistence()
                sanitizedCheckIn = merged
                applyLatestCheckInFields(to: person, data: merged)
                _ = CheckInRepository(context: ctx).createRecord(createdAt: checkInDate, for: person, data: merged)
                reminderHandler?.handleCheckIn(painLevel: merged.painLevel, at: checkInDate)
            }

            try peopleRepo.save()
        }

        if let personID, let sanitizedCheckIn {
            escalationHandler?.handleCheckIn(personID: personID, data: sanitizedCheckIn, at: checkInDate)
            syncHandler?.enqueueForSync(personID: personID, createdAt: checkInDate, data: sanitizedCheckIn)
        }
    }

    func updatePerson(personID: NSManagedObjectID, name: String, gender: Gender?, dob: Date?, checkInData: PersonCheckInData?) throws {
        let name = InputSanitizer.personName(name) ?? ""
        var sanitizedCheckIn: PersonCheckInData?
        let checkInDate = Date()

        try coreDataStack.performBackgroundTaskAndWait { ctx in
            let peopleRepo = PersonRepository(context: ctx)
            guard let person = try ctx.existingObject(with: personID) as? Person else { return }

            person.name = name
            if person.entity.attributesByName["nameLowercased"] != nil {
                person.nameLowercasedValue = Person.normalizedLowercasedName(from: name)
            }
            person.genderEnum = gender
            person.dob = dob

            if let checkInData {
                let sanitized = checkInData.sanitized()
                let merged = sanitized.mergedForPersistence()
                sanitizedCheckIn = merged
                applyLatestCheckInFields(to: person, data: merged)
                _ = CheckInRepository(context: ctx).createRecord(createdAt: checkInDate, for: person, data: merged)
                reminderHandler?.handleCheckIn(painLevel: merged.painLevel, at: checkInDate)
            }

            try peopleRepo.save()
        }

        if let sanitizedCheckIn {
            escalationHandler?.handleCheckIn(personID: personID, data: sanitizedCheckIn, at: checkInDate)
            syncHandler?.enqueueForSync(personID: personID, createdAt: checkInDate, data: sanitizedCheckIn)
        }
    }

    func deletePerson(personID: NSManagedObjectID) throws {
        try coreDataStack.performBackgroundTaskAndWait { ctx in
            let peopleRepo = PersonRepository(context: ctx)
            if let person = try? ctx.existingObject(with: personID) as? Person {
                peopleRepo.deletePerson(person)
            }
            try peopleRepo.save()
        }
    }
}

private extension PersonService {
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
