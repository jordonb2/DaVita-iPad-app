import Foundation
import CoreData

/// Business logic layer for people + visit history.
final class PersonService {
    private let peopleRepo: PersonRepository
    private let checkInService: CheckInService

    init(peopleRepo: PersonRepository, checkInService: CheckInService) {
        self.peopleRepo = peopleRepo
        self.checkInService = checkInService
    }

    @discardableResult
    func addPerson(name: String, gender: String?, dob: Date?, checkInData: PersonCheckInData?) throws -> Person {
        let person = peopleRepo.createPerson(name: name, gender: gender, dob: dob)

        if let checkInData {
            try checkInService.writeCheckIn(for: person, data: checkInData, savingUsing: peopleRepo.save)
        } else {
            try peopleRepo.save()
        }

        return person
    }

    func updatePerson(_ person: Person, name: String, gender: String?, dob: Date?, checkInData: PersonCheckInData?) throws {
        person.name = name
        person.gender = gender
        person.dob = dob

        if let checkInData {
            try checkInService.writeCheckIn(for: person, data: checkInData, savingUsing: peopleRepo.save)
        } else {
            try peopleRepo.save()
        }
    }

    func deletePerson(_ person: Person) throws {
        peopleRepo.deletePerson(person)
        try peopleRepo.save()
    }
}
