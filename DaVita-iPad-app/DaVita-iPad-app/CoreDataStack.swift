//
//  CoreDataStack.swift
//  DaVita-iPad-app
//
//  Created by Jordon Bowen on 10/3/25.
//

import Foundation
import CoreData

final class CoreDataStack {
    static let shared = CoreDataStack()
    private init() {}

    lazy var persistentContainer: NSPersistentContainer = {
        let c = NSPersistentContainer(name: "RecordsModel")
        if let storeDescription = c.persistentStoreDescriptions.first {
            storeDescription.shouldMigrateStoreAutomatically = true
            storeDescription.shouldInferMappingModelAutomatically = true
        }
        c.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Core Data load error: \(error)")
            }
            // Fail fast if the on-disk store isn't compatible with the current model.
            // This catches non-lightweight migration changes early (during startup) rather than later at runtime.
            CoreDataStack.validateStoreCompatibility(container: c)
        }
        c.viewContext.automaticallyMergesChangesFromParent = true
        return c
    }()

    var viewContext: NSManagedObjectContext { persistentContainer.viewContext }

    func newBackgroundContext() -> NSManagedObjectContext {
        let ctx = persistentContainer.newBackgroundContext()
        ctx.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return ctx
    }

    func saveContext(_ context: NSManagedObjectContext? = nil) {
        let ctx = context ?? viewContext
        if ctx.hasChanges { try? ctx.save() }
    }
}

private extension CoreDataStack {
    static func validateStoreCompatibility(container: NSPersistentContainer) {
        let coordinator = container.persistentStoreCoordinator
        let model = container.managedObjectModel

        for store in coordinator.persistentStores {
            guard let url = store.url else { continue }
            do {
                let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
                    ofType: store.type,
                    at: url,
                    options: store.options
                )

                guard model.isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata) else {
                    let storeName = url.lastPathComponent
                    let message = "Persistent store '\(storeName)' is not compatible with the current model. " +
                        "This likely means a model change requires a manual migration (not lightweight)."
                    fatalError(message)
                }
            } catch {
                let storeName = url.lastPathComponent
                fatalError("Failed reading Core Data store metadata for '\(storeName)': \(error)")
            }
        }
    }
}

