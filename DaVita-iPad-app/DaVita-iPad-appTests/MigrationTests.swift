import XCTest
import CoreData

@testable import DaVita_iPad_app

final class MigrationTests: XCTestCase {

    func testLightweightMigrationFromV1ToCurrentModel() throws {
        let bundle = Bundle(for: CoreDataStack.self)
        guard let momdURL = bundle.url(forResource: "RecordsModel", withExtension: "momd") else {
            XCTFail("Missing RecordsModel.momd in test bundle")
            return
        }

        let v1MomURL = momdURL.appendingPathComponent("RecordsModel_v1.mom")
        guard FileManager.default.fileExists(atPath: v1MomURL.path) else {
            XCTFail("Missing RecordsModel_v1.mom. Ensure the model is versioned and v1 is included.")
            return
        }

        guard let v1Model = NSManagedObjectModel(contentsOf: v1MomURL) else {
            XCTFail("Failed to load v1 model")
            return
        }

        guard let currentModel = NSManagedObjectModel.mergedModel(from: [bundle]) else {
            XCTFail("Failed to load current model from bundle")
            return
        }

        // Build a store using the v1 model.
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("migration_test_\(UUID().uuidString)")
            .appendingPathExtension("sqlite")

        let v1Coordinator = NSPersistentStoreCoordinator(managedObjectModel: v1Model)
        _ = try v1Coordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: storeURL,
            options: nil
        )

        let v1Context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        v1Context.persistentStoreCoordinator = v1Coordinator

        try v1Context.performAndWaitThrowing {
            let person = NSEntityDescription.insertNewObject(forEntityName: "Person", into: v1Context)
            person.setValue(UUID(), forKey: "id")
            person.setValue(Date(), forKey: "createdAt")
            person.setValue("Migration Person", forKey: "name")
            try v1Context.save()
        }

        // Now open the same store with the current model using lightweight migration.
        let currentCoordinator = NSPersistentStoreCoordinator(managedObjectModel: currentModel)
        let options: [AnyHashable: Any] = [
            NSMigratePersistentStoresAutomaticallyOption: true,
            NSInferMappingModelAutomaticallyOption: true
        ]

        _ = try currentCoordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: storeURL,
            options: options
        )
    }

    func testInferredMappingModelExistsFromV1ToCurrent() throws {
        let bundle = Bundle(for: CoreDataStack.self)
        guard let momdURL = bundle.url(forResource: "RecordsModel", withExtension: "momd") else {
            XCTFail("Missing RecordsModel.momd in test bundle")
            return
        }

        let v1MomURL = momdURL.appendingPathComponent("RecordsModel_v1.mom")
        guard let v1Model = NSManagedObjectModel(contentsOf: v1MomURL) else {
            XCTFail("Failed to load v1 model")
            return
        }

        guard let currentModel = NSManagedObjectModel.mergedModel(from: [bundle]) else {
            XCTFail("Failed to load current model from bundle")
            return
        }

        // Throws if the mapping cannot be inferred (i.e., not lightweight migratable).
        _ = try NSMappingModel.inferredMappingModel(forSourceModel: v1Model, destinationModel: currentModel)
    }

    func testCoreDataStackConfiguredForLightweightMigration() {
        let stack = CoreDataStack()
        let desc = stack.persistentContainer.persistentStoreDescriptions.first
        XCTAssertEqual(desc?.shouldMigrateStoreAutomatically, true)
        XCTAssertEqual(desc?.shouldInferMappingModelAutomatically, true)
    }
}


