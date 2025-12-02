import Foundation
import CoreData

protocol PersonRepositorying {
    func makePeopleFRC(delegate: NSFetchedResultsControllerDelegate?) -> NSFetchedResultsController<Person>

    func createPerson(name: String, gender: Gender?, dob: Date?) -> Person

    func deletePerson(_ person: Person)
    func save() throws
}

/// Pure persistence layer for Person CRUD.
final class PersonRepository: PersonRepositorying {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func makePeopleFRC(delegate: NSFetchedResultsControllerDelegate?) -> NSFetchedResultsController<Person> {
        let fetch: NSFetchRequest<Person> = Person.fetchRequest()
        fetch.sortDescriptors = [
            NSSortDescriptor(key: "createdAt", ascending: false),
            NSSortDescriptor(key: "name", ascending: true)
        ]
        // Stream results in batches to keep memory stable for large datasets.
        fetch.fetchBatchSize = 50
        let controller = NSFetchedResultsController(
            fetchRequest: fetch,
            managedObjectContext: context,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        controller.delegate = delegate
        return controller
    }

    func createPerson(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        name: String,
        gender: Gender?,
        dob: Date?
    ) -> Person {
        let p = Person(context: context)
        // Enforce non-optional identity + timestamps at creation time.
        p.id = id
        p.createdAt = createdAt
        p.name = name
        p.genderEnum = gender
        p.dob = dob
#if DEBUG
        assert(p.id != nil && p.createdAt != nil, "Person must have id + createdAt at creation time")
#endif
        return p
    }

    func createPerson(name: String, gender: Gender?, dob: Date?) -> Person {
        createPerson(id: UUID(), createdAt: Date(), name: name, gender: gender, dob: dob)
    }

    func deletePerson(_ person: Person) {
        context.delete(person)
    }

    func save() throws {
        if context.hasChanges {
            try context.save()
        }
    }
}
