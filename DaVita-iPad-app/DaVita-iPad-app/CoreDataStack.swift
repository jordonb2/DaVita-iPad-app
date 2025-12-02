//
//  CoreDataStack.swift
//  DaVita-iPad-app
//
//  Created by Jordon Bowen on 10/3/25.
//

import Foundation
import CoreData

protocol CoreDataStacking {
    var viewContext: NSManagedObjectContext { get }
    func newBackgroundContext() -> NSManagedObjectContext
}

extension CoreDataStacking {
    /// Standard background write transaction (private queue context).
    ///
    /// - Important: Keeps Core Data saves off the main/view context.
    func performBackgroundTaskAndWait<T>(_ block: (NSManagedObjectContext) throws -> T) throws -> T {
        let ctx = newBackgroundContext()
        var result: Result<T, Error>!
        ctx.performAndWait {
            result = Result { try block(ctx) }
        }
        return try result.get()
    }
}

final class CoreDataStack: CoreDataStacking {
    init() {}

    static var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("UI_TESTING")
    }

    lazy var persistentContainer: NSPersistentContainer = {
        let c = NSPersistentContainer(name: "RecordsModel")
        if let storeDescription = c.persistentStoreDescriptions.first {
            storeDescription.shouldMigrateStoreAutomatically = true
            storeDescription.shouldInferMappingModelAutomatically = true
            // Encrypt-at-rest via iOS Data Protection when the device is locked.
            // This is the lowest-friction option and requires no third-party dependencies.
            storeDescription.setOption(FileProtectionType.complete as NSObject, forKey: NSPersistentStoreFileProtectionKey)
        }
        c.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Core Data load error: \(error)")
            }
            // Fail fast if the on-disk store isn't compatible with the current model.
            // This catches non-lightweight migration changes early (during startup) rather than later at runtime.
            CoreDataStack.validateStoreCompatibility(container: c)
            CoreDataStack.enforceStoreFileProtection(container: c)
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


    static func enforceStoreFileProtection(container: NSPersistentContainer) {
        let coordinator = container.persistentStoreCoordinator
        for store in coordinator.persistentStores {
            guard let url = store.url else { continue }
            setProtectionComplete(for: url)
            // SQLite sidecars
            setProtectionComplete(for: url.deletingPathExtension().appendingPathExtension(url.pathExtension + "-wal"))
            setProtectionComplete(for: url.deletingPathExtension().appendingPathExtension(url.pathExtension + "-shm"))
        }
    }

    static func setProtectionComplete(for url: URL) {
        let path = url.path
        guard FileManager.default.fileExists(atPath: path) else { return }
        do {
            try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: path)
        } catch {
            AppLog.persistence.error("Failed to set file protection for \(url.lastPathComponent, privacy: .public): \(error, privacy: .public)")
        }
    }
}

