import Foundation
import CoreData

/// Performs lightweight Core Data integrity checks and repairs.
///
/// Transaction boundary:
/// - Runs on a background context and saves once if changes are needed.
///
/// Goals:
/// - Ensure required identity fields (`id`, `createdAt`) are present.
/// - Detect (and log) duplicate IDs where uniqueness is expected.
final class DataIntegrityService {
    private let coreDataStack: CoreDataStacking

    init(coreDataStack: CoreDataStacking) {
        self.coreDataStack = coreDataStack
    }

    func runInBackground() {
        let ctx = coreDataStack.newBackgroundContext()
        ctx.perform { [weak self] in
            guard let self else { return }
            do {
                try self.repairMissingRequiredFields(in: ctx)
                try self.logDuplicateIDsIfAny(in: ctx)

                if ctx.hasChanges {
                    try ctx.save()
                }
            } catch {
                AppLog.persistence.error("Data integrity check failed: \(error, privacy: .public)")
            }
        }
    }

    // MARK: - Repairs

    private func repairMissingRequiredFields(in ctx: NSManagedObjectContext) throws {
        try repair(entityName: "Person", in: ctx)
        try repair(entityName: "CheckInRecord", in: ctx)
        try repair(entityName: "CheckInAnalyticsEvent", in: ctx)
    }

    private func repair(entityName: String, in ctx: NSManagedObjectContext) throws {
        let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
        request.fetchBatchSize = 200
        request.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [
            NSPredicate(format: "id == nil"),
            NSPredicate(format: "createdAt == nil")
        ])

        let objects = try ctx.fetch(request)
        guard !objects.isEmpty else { return }

        for obj in objects {
            if obj.value(forKey: "id") == nil {
                obj.setValue(UUID(), forKey: "id")
            }
            if obj.value(forKey: "createdAt") == nil {
                obj.setValue(Date(), forKey: "createdAt")
            }
        }

        AppLog.persistence.warning("Repaired missing required fields for \(objects.count, privacy: .public) \(entityName, privacy: .public) object(s)")
    }

    // MARK: - Duplicate detection

    private func logDuplicateIDsIfAny(in ctx: NSManagedObjectContext) throws {
        try logDuplicateIDs(entityName: "Person", in: ctx)
        try logDuplicateIDs(entityName: "CheckInRecord", in: ctx)
        try logDuplicateIDs(entityName: "CheckInAnalyticsEvent", in: ctx)
    }

    private func logDuplicateIDs(entityName: String, in ctx: NSManagedObjectContext) throws {
        // Group by id and count occurrences; log any ids with count > 1.
        let request = NSFetchRequest<NSDictionary>(entityName: entityName)
        request.resultType = .dictionaryResultType
        request.fetchBatchSize = 200
        request.propertiesToGroupBy = ["id"]

        let countDesc = NSExpressionDescription()
        countDesc.name = "count"
        countDesc.expression = NSExpression(forFunction: "count:", arguments: [NSExpression(forKeyPath: "id")])
        countDesc.expressionResultType = .integer64AttributeType

        request.propertiesToFetch = ["id", countDesc]
        request.havingPredicate = NSPredicate(format: "count > 1")

        let rows = try ctx.fetch(request)
        guard !rows.isEmpty else { return }

        AppLog.persistence.error("Detected duplicate IDs in \(entityName, privacy: .public): \(rows.count, privacy: .public) duplicate group(s)")
    }
}


