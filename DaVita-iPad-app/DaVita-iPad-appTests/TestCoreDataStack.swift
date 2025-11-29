import Foundation
import CoreData

@testable import DaVita_iPad_app

/// In-memory Core Data stack for unit tests.
final class TestCoreDataStack: CoreDataStacking {
    let persistentContainer: NSPersistentContainer

    init() {
        // Load the same model as the app.
        guard let modelURL = Bundle(for: CoreDataStack.self).url(forResource: "RecordsModel", withExtension: "momd"),
              let model = NSManagedObjectModel(contentsOf: modelURL) else {
            fatalError("Failed to load RecordsModel.momd")
        }

        persistentContainer = NSPersistentContainer(name: "RecordsModel", managedObjectModel: model)

        let desc = NSPersistentStoreDescription()
        desc.type = NSInMemoryStoreType
        desc.shouldAddStoreAsynchronously = false
        persistentContainer.persistentStoreDescriptions = [desc]

        var loadError: Error?
        persistentContainer.loadPersistentStores { _, error in
            loadError = error
        }
        if let loadError {
            fatalError("In-memory store load error: \(loadError)")
        }

        persistentContainer.viewContext.automaticallyMergesChangesFromParent = true
        persistentContainer.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    var viewContext: NSManagedObjectContext { persistentContainer.viewContext }

    func newBackgroundContext() -> NSManagedObjectContext {
        let ctx = persistentContainer.newBackgroundContext()
        ctx.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return ctx
    }
}

extension NSManagedObjectContext {
    /// Convenience for `performAndWait` blocks that throw.
    func performAndWaitThrowing<T>(_ block: () throws -> T) throws -> T {
        var result: Result<T, Error>!
        performAndWait {
            result = Result { try block() }
        }
        return try result.get()
    }
}
