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

    private let context: NSManagedObjectContext
    private lazy var frc: NSFetchedResultsController<Person> = {
        let fetch: NSFetchRequest<Person> = Person.fetchRequest()
        // Sort newest first (by createdAt). Add secondary sort by name for stability.
        fetch.sortDescriptors = [
            NSSortDescriptor(key: "createdAt", ascending: false),
            NSSortDescriptor(key: "name", ascending: true)
        ]
        let controller = NSFetchedResultsController(
            fetchRequest: fetch,
            managedObjectContext: context,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        controller.delegate = self
        return controller
    }()

    init(context: NSManagedObjectContext = CoreDataStack.shared.viewContext) {
        self.context = context
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
        
        let p = Person(context: context)
        p.id = UUID()
        p.name = trimmed
        p.gender = gender
        p.dob = dob
        p.createdAt = Date()
        if let checkInData {
            p.checkInPain = checkInData.painLevel ?? 0
            p.checkInEnergy = checkInData.energyLevel
            p.checkInMood = checkInData.mood
            p.checkInSymptoms = checkInData.symptoms
            p.checkInConcerns = checkInData.concerns
            p.checkInTeamNote = checkInData.teamNote
        }
        save()
        logPerson(p, context: "ADD")
    }

    func delete(_ person: Person) {
        context.delete(person)
        save()
    }
    
    func update(_ person: Person, name: String, gender: String?, dob: Date?, checkInData: PersonCheckInData? = nil) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            print("Refusing to update Person with empty name")
            return
        }
        
        person.name   = trimmed
        person.gender = gender
        person.dob    = dob
        if let checkInData {
            person.checkInPain = checkInData.painLevel ?? 0
            person.checkInEnergy = checkInData.energyLevel
            person.checkInMood = checkInData.mood
            person.checkInSymptoms = checkInData.symptoms
            person.checkInConcerns = checkInData.concerns
            person.checkInTeamNote = checkInData.teamNote
        }
        save()
        logPerson(person, context: "UPDATE")
    }

    private func save() {
        do {
            try context.save()
        } catch {
            print("Core Data save error: \(error)")
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
