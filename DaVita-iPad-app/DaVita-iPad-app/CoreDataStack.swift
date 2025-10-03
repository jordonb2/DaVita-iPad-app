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
        c.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Core Data load error: \(error)")
            }
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
