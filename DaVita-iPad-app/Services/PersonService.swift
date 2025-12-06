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

    init(coreDataStack: CoreDataStacking) {
        self.coreDataStack = coreDataStack
    }

    func addPerson(name: String, gender: Gender?, dob: Date?, checkInData: PersonCheckInData?) throws {
        let name = InputSanitizer.personName(name) ?? ""
        try coreDataStack.performBackgroundTaskAndWait { ctx in
            let peopleRepo = PersonRepository(context: ctx)
            let person = peopleRepo.createPerson(name: name, gender: gender, dob: dob)

            if let checkInData {
                let sanitized = checkInData.sanitized()
                applyLatestCheckInFields(to: person, data: sanitized)
                _ = CheckInRepository(context: ctx).createRecord(createdAt: Date(), for: person, data: sanitized)
            }

            try peopleRepo.save()
        }
    }

    func updatePerson(personID: NSManagedObjectID, name: String, gender: Gender?, dob: Date?, checkInData: PersonCheckInData?) throws {
        let name = InputSanitizer.personName(name) ?? ""
        try coreDataStack.performBackgroundTaskAndWait { ctx in
            let peopleRepo = PersonRepository(context: ctx)
            guard let person = try ctx.existingObject(with: personID) as? Person else { return }

            person.name = name
            person.nameLowercasedValue = Person.normalizedLowercasedName(from: name)
            person.genderEnum = gender
            person.dob = dob

            if let checkInData {
                let sanitized = checkInData.sanitized()
                applyLatestCheckInFields(to: person, data: sanitized)
                _ = CheckInRepository(context: ctx).createRecord(createdAt: Date(), for: person, data: sanitized)
            }

            try peopleRepo.save()
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
