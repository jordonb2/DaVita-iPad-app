import Foundation
import CoreData

/// Business logic layer for people + visit history.
final class PersonService {
    private let peopleRepo: PersonRepository
    private let checkInRepo: CheckInRepository

    init(peopleRepo: PersonRepository, checkInRepo: CheckInRepository) {
        self.peopleRepo = peopleRepo
        self.checkInRepo = checkInRepo
    }

    @discardableResult
    func addPerson(name: String, gender: String?, dob: Date?, checkInData: PersonCheckInData?) throws -> Person {
        let person = peopleRepo.createPerson(name: name, gender: gender, dob: dob)
        if let checkInData {
            applyLatestCheckInFields(to: person, data: checkInData)
            checkInRepo.createRecord(for: person, data: checkInData)
        }
        try peopleRepo.save()
        return person
    }

    func updatePerson(_ person: Person, name: String, gender: String?, dob: Date?, checkInData: PersonCheckInData?) throws {
        person.name = name
        person.gender = gender
        person.dob = dob
        if let checkInData {
            applyLatestCheckInFields(to: person, data: checkInData)
            checkInRepo.createRecord(for: person, data: checkInData)
        }
        try peopleRepo.save()
    }

    func deletePerson(_ person: Person) throws {
        peopleRepo.deletePerson(person)
        try peopleRepo.save()
    }

    private func applyLatestCheckInFields(to person: Person, data: PersonCheckInData) {
        person.checkInPain = data.painLevel ?? 0
        person.checkInEnergy = data.energyLevel
        person.checkInMood = data.mood
        person.checkInSymptoms = data.symptoms
        person.checkInConcerns = data.concerns
        person.checkInTeamNote = data.teamNote
    }
}
