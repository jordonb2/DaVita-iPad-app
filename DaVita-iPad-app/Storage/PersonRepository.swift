import Foundation
import CoreData

/// Pure persistence layer for Person CRUD.
final class PersonRepository {
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
        let controller = NSFetchedResultsController(
            fetchRequest: fetch,
            managedObjectContext: context,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        controller.delegate = delegate
        return controller
    }

    func createPerson(name: String, gender: String?, dob: Date?) -> Person {
        let p = Person(context: context)
        p.id = UUID()
        p.name = name
        p.gender = gender
        p.dob = dob
        p.createdAt = Date()
        return p
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
