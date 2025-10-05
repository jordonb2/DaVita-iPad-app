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

    func add(name: String, gender: String? = nil, dob: Date? = nil) {
        let p = Person(context: context)
        p.id = UUID()
        p.name = name
        p.gender = gender
        p.dob = dob
        p.createdAt = Date()
        save()
    }

    func delete(_ person: Person) {
        context.delete(person)
        save()
    }
    
    func update(_ person: Person, name: String, gender: String?, dob: Date?) {
        person.name   = name
        person.gender = gender
        person.dob    = dob
        save()
    }

    private func save() {
        do {
            try context.save()
        } catch {
            print("Core Data save error: \(error)")
        }
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
