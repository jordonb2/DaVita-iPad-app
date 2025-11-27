//
//  PeopleListViewModel.swift
//  DaVita-iPad-app
//
//  Created by Jordon Bowen on 10/4/25.
//

import Foundation
import CoreData
import Combine

final class PeopleListViewModel: NSObject {
    // Published array the view observes
    @Published private(set) var people: [Person] = []

    private let personService: PersonService
    private let peopleRepo: PersonRepository

    private let context: NSManagedObjectContext
    private lazy var frc: NSFetchedResultsController<Person> = {
        return peopleRepo.makePeopleFRC(delegate: self)
    }()

    init(coreDataStack: CoreDataStack = CoreDataStack.shared,
         context: NSManagedObjectContext? = nil) {
        let ctx = context ?? coreDataStack.viewContext
        self.context = ctx
        self.peopleRepo = PersonRepository(context: ctx)
        let checkInService = CheckInService(coreDataStack: coreDataStack)
        self.personService = PersonService(peopleRepo: peopleRepo, checkInService: checkInService)
        super.init()
        do {
            try frc.performFetch()
            people = frc.fetchedObjects ?? []
        } catch {
            print("FRC performFetch error: \(error)")
        }

    }

    // MARK: - CRUD

    func add(name: String, gender: String? = nil, dob: Date? = nil, checkInData: PersonCheckInData? = nil) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            print("Refusing to add Person with empty name")
            return
        }

        do {
            let p = try personService.addPerson(name: trimmed, gender: gender, dob: dob, checkInData: checkInData)
            logPerson(p, context: "ADD")
        } catch {
            print("Add person error: \(error)")
        }
    }

    func delete(_ person: Person) {
        do {
            try personService.deletePerson(person)
        } catch {
            print("Delete person error: \(error)")
        }
    }
    
    func update(_ person: Person, name: String, gender: String?, dob: Date?, checkInData: PersonCheckInData? = nil) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            print("Refusing to update Person with empty name")
            return
        }

        do {
            try personService.updatePerson(person, name: trimmed, gender: gender, dob: dob, checkInData: checkInData)
            logPerson(person, context: "UPDATE")
        } catch {
            print("Update person error: \(error)")
        }
    }

    private func logPerson(_ person: Person, context: String) {
#if DEBUG
        let name = person.name ?? ""
        let dobText: String
        if let dob = person.dob {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            dobText = formatter.string(from: dob)
        } else {
            dobText = "—"
        }

        let gender = person.gender ?? "—"
        let pain = person.checkInPain
        let energy = person.checkInEnergy ?? "—"
        let mood = person.checkInMood ?? "—"
        let symptoms = person.checkInSymptoms ?? "—"
        let concerns = person.checkInConcerns ?? "—"
        let teamNote = person.checkInTeamNote ?? "—"

        print("[\(context)] Person saved → Name: \(name), DOB: \(dobText), Gender: \(gender), CheckIn(pain: \(pain), energy: \(energy), mood: \(mood), symptoms: \(symptoms), concerns: \(concerns), teamNote: \(teamNote))")
#endif
    }

    // Convenience
    func person(at indexPath: IndexPath) -> Person {
        return people[indexPath.row]
    }

    var count: Int { people.count }
}

// MARK: - NSFetchedResultsControllerDelegate
extension PeopleListViewModel: NSFetchedResultsControllerDelegate {
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        people = frc.fetchedObjects ?? []
    }
}

