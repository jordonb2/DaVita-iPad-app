import Foundation
import CoreData

@testable import DaVita_iPad_app

/// In-memory Core Data stack for unit tests (fast + isolated).
final class TestCoreDataStack: CoreDataStacking {
    let persistentContainer: NSPersistentContainer

    init() {
        // Prefer a merged model so tests don't depend on a specific `.momd` filename/path.
        let bundles = [Bundle(for: CoreDataStack.self)]
        guard let model = NSManagedObjectModel.mergedModel(from: bundles) else {
            fatalError("Failed to load merged Core Data model from app bundle")
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
