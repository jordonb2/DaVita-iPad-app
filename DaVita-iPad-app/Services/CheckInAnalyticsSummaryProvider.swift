import Foundation
import CoreData

protocol CheckInAnalyticsSummaryProviding {
    func makeSummary(since startDate: Date?, sampleLimit: Int?) throws -> CheckInAnalyticsSummaryProvider.Summary
}

extension CheckInAnalyticsSummaryProviding {
    func makeSummary(since startDate: Date? = nil) throws -> CheckInAnalyticsSummaryProvider.Summary {
        try makeSummary(since: startDate, sampleLimit: nil)
    }
}

final class CheckInAnalyticsSummaryProvider: CheckInAnalyticsSummaryProviding {

    struct Options {
        /// Optional cap on the number of analytics events considered (newest first).
        /// Useful to keep UI dashboards responsive on very large datasets.
        let sampleLimit: Int?

        /// Whether to reset private queue contexts after aggregation to release faults.
        let shouldResetBackgroundContext: Bool

        static let `default` = Options(sampleLimit: nil, shouldResetBackgroundContext: true)

        /// Reads `ANALYTICS_SAMPLE_LIMIT` from the process environment when present.
        static func dashboardDefault(environment: [String: String] = ProcessInfo.processInfo.environment) -> Options {
            if
                let raw = environment["ANALYTICS_SAMPLE_LIMIT"],
                let parsed = Int(raw),
                parsed > 0
            {
                return Options(sampleLimit: parsed, shouldResetBackgroundContext: true)
            }
            return .default
        }
    }

    struct Summary {
        static var empty: Summary {
            Summary(
                totalPresented: 0,
                totalSubmitted: 0,
                totalSkipped: 0,
                totalDismissed: 0,
                completionRate: 0,
                skipRate: 0,
                averageCompletionSeconds: 0,
                averageSkipSeconds: 0,
                stepFirstInteractionCounts: [:],
                highPainRate: 0,
                lowEnergyRate: 0,
                symptomCategoryCounts: [:],
                concernCategoryCounts: [:],
                submissionsByDaypart: [:]
            )
        }

        let totalPresented: Int
        let totalSubmitted: Int
        let totalSkipped: Int
        let totalDismissed: Int
        let completionRate: Double
        let skipRate: Double
        let averageCompletionSeconds: Double
        let averageSkipSeconds: Double
        let stepFirstInteractionCounts: [CheckInAnalyticsStep: Int]
        let highPainRate: Double
        let lowEnergyRate: Double
        let symptomCategoryCounts: [String: Int]
        let concernCategoryCounts: [String: Int]
        let submissionsByDaypart: [Daypart: Int]
    }

    private struct FetchScope {
        let startDate: Date?
        let samplingPredicate: NSPredicate?
        let hasResults: Bool
    }

    private enum Constants {
        static let maxCategoryNameLength = 64
    }

    private let coreDataStack: CoreDataStacking?
    private let context: NSManagedObjectContext?
    private let options: Options

    init(coreDataStack: CoreDataStacking, options: Options = .dashboardDefault()) {
        self.coreDataStack = coreDataStack
        self.context = nil
        self.options = options
    }

    init(context: NSManagedObjectContext, options: Options = .dashboardDefault()) {
        self.coreDataStack = nil
        self.context = context
        self.options = options
    }

    func makeSummary(since startDate: Date? = nil, sampleLimit: Int? = nil) throws -> Summary {
        let effectiveSampleLimit = sampleLimit ?? options.sampleLimit

        if let coreDataStack {
            return try coreDataStack.performBackgroundTaskAndWait { ctx in
                ctx.retainsRegisteredObjects = false
                let summary = try self.computeSummary(in: ctx, startDate: startDate, sampleLimit: effectiveSampleLimit)
                if self.options.shouldResetBackgroundContext {
                    ctx.reset()
                }
                return summary
            }
        }

        guard let context else {
            AppLog.analytics.error("Analytics summary provider missing context")
            return .empty
        }

        var summary: Summary = .empty
        var thrownError: Error?
        context.performAndWait {
            do {
                summary = try self.computeSummary(in: context, startDate: startDate, sampleLimit: effectiveSampleLimit)
            } catch {
                thrownError = error
            }
        }
        if let thrownError {
            throw thrownError
        }
        return summary
    }

    // MARK: - Aggregates

    private func computeSummary(in context: NSManagedObjectContext, startDate: Date?, sampleLimit: Int?) throws -> Summary {
        let scope = try makeScope(in: context, startDate: startDate, sampleLimit: sampleLimit)
        guard scope.hasResults else {
            return .empty
        }

        let eventCounts = try fetchEventTypeCounts(scope: scope, in: context)
        let stepCounts = try fetchStepInteractionCounts(scope: scope, in: context)
        let submissionDurationsAverage = try fetchAverageDuration(for: .submitted, scope: scope, in: context)
        let skipDurationsAverage = try fetchAverageDuration(for: .skipped, scope: scope, in: context)
        let submissionsByDaypart = try fetchDaypartCounts(scope: scope, in: context)

        let highPainSubmitted = try countSubmitted(where: NSPredicate(format: "painBucket == %d", CheckInAnalyticsPainBucket.high.rawValue), scope: scope, in: context)
        let lowEnergySubmitted = try countSubmitted(where: NSPredicate(format: "energyBucket == %d", EnergyBucket.low.rawValue), scope: scope, in: context)

        let categoryCounts = try fetchCategoryCounts(scope: scope, in: context)

        let presentedCount = eventCounts[.stepFirstInteracted, default: 0] +
            eventCounts[.submitted, default: 0] +
            eventCounts[.skipped, default: 0] +
            eventCounts[.dismissed, default: 0]

        let submittedCount = eventCounts[.submitted, default: 0]
        let skippedCount = eventCounts[.skipped, default: 0]
        let dismissedCount = eventCounts[.dismissed, default: 0]

        let totalCompletedOrSkipped = submittedCount + skippedCount + dismissedCount
        let completionRate = totalCompletedOrSkipped == 0 ? 0 : Double(submittedCount) / Double(totalCompletedOrSkipped)
        let skipRate = totalCompletedOrSkipped == 0 ? 0 : Double(skippedCount) / Double(totalCompletedOrSkipped)

        let highPainRate = submittedCount == 0 ? 0 : Double(highPainSubmitted) / Double(submittedCount)
        let lowEnergyRate = submittedCount == 0 ? 0 : Double(lowEnergySubmitted) / Double(submittedCount)

        return Summary(
            totalPresented: presentedCount,
            totalSubmitted: submittedCount,
            totalSkipped: skippedCount,
            totalDismissed: dismissedCount,
            completionRate: completionRate,
            skipRate: skipRate,
            averageCompletionSeconds: submissionDurationsAverage,
            averageSkipSeconds: skipDurationsAverage,
            stepFirstInteractionCounts: stepCounts,
            highPainRate: highPainRate,
            lowEnergyRate: lowEnergyRate,
            symptomCategoryCounts: categoryCounts.symptomCounts,
            concernCategoryCounts: categoryCounts.concernCounts,
            submissionsByDaypart: submissionsByDaypart
        )
    }

    private func makeScope(in context: NSManagedObjectContext, startDate: Date?, sampleLimit: Int?) throws -> FetchScope {
        guard let limit = sampleLimit, limit > 0 else {
            return FetchScope(startDate: startDate, samplingPredicate: nil, hasResults: true)
        }

        let idRequest = NSFetchRequest<NSManagedObjectID>(entityName: "CheckInAnalyticsEvent")
        idRequest.resultType = .managedObjectIDResultType
        idRequest.fetchLimit = limit
        idRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        idRequest.includesPropertyValues = false
        idRequest.includesPendingChanges = false
        if let startDate {
            idRequest.predicate = NSPredicate(format: "createdAt >= %@", startDate as NSDate)
        }

        let ids = try context.fetch(idRequest)
        guard !ids.isEmpty else {
            return FetchScope(startDate: startDate, samplingPredicate: NSPredicate(value: false), hasResults: false)
        }

        let predicate = NSPredicate(format: "SELF IN %@", ids)
        return FetchScope(startDate: startDate, samplingPredicate: predicate, hasResults: true)
    }

    private func basePredicates(for scope: FetchScope) -> [NSPredicate] {
        var predicates: [NSPredicate] = []
        if let start = scope.startDate {
            predicates.append(NSPredicate(format: "createdAt >= %@", start as NSDate))
        }
        if let sampling = scope.samplingPredicate {
            predicates.append(sampling)
        }
        return predicates
    }

    private func compoundPredicate(for scope: FetchScope, additional: [NSPredicate]) -> NSPredicate? {
        let predicates = basePredicates(for: scope) + additional
        guard !predicates.isEmpty else { return nil }
        return NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }

    private func fetchEventTypeCounts(scope: FetchScope, in context: NSManagedObjectContext) throws -> [CheckInAnalyticsEventType: Int] {
        let request = NSFetchRequest<NSDictionary>(entityName: "CheckInAnalyticsEvent")
        request.resultType = .dictionaryResultType
        request.propertiesToGroupBy = ["eventType"]
        request.includesPendingChanges = false

        let countDescription = NSExpressionDescription()
        countDescription.name = "count"
        countDescription.expression = NSExpression(forFunction: "count:", arguments: [NSExpression(forKeyPath: "eventType")])
        countDescription.expressionResultType = .integer32AttributeType

        request.propertiesToFetch = ["eventType", countDescription]
        request.predicate = compoundPredicate(for: scope, additional: [NSPredicate(format: "eventType != nil")])

        let rows = try context.fetch(request)
        var counts: [CheckInAnalyticsEventType: Int] = [:]
        for dict in rows {
            guard
                let raw = dict["eventType"] as? String,
                let type = CheckInAnalyticsEventType(rawValue: raw),
                let count = dict["count"] as? NSNumber
            else { continue }
            counts[type] = count.intValue
        }
        return counts
    }

    private func fetchAverageDuration(for type: CheckInAnalyticsEventType, scope: FetchScope, in context: NSManagedObjectContext) throws -> Double {
        let request = NSFetchRequest<NSDictionary>(entityName: "CheckInAnalyticsEvent")
        request.resultType = .dictionaryResultType
        request.includesPendingChanges = false

        let avgDescription = NSExpressionDescription()
        avgDescription.name = "avgDuration"
        avgDescription.expression = NSExpression(forFunction: "average:", arguments: [NSExpression(forKeyPath: "durationSeconds")])
        avgDescription.expressionResultType = .doubleAttributeType

        let predicates: [NSPredicate] = [
            NSPredicate(format: "eventType == %@", type.rawValue),
            NSPredicate(format: "durationSeconds >= 0")
        ]
        request.predicate = compoundPredicate(for: scope, additional: predicates)
        request.propertiesToFetch = [avgDescription]

        let rows = try context.fetch(request)
        let value = (rows.first?["avgDuration"] as? NSNumber)?.doubleValue ?? 0
        return value
    }

    private func fetchStepInteractionCounts(scope: FetchScope, in context: NSManagedObjectContext) throws -> [CheckInAnalyticsStep: Int] {
        let request = NSFetchRequest<NSDictionary>(entityName: "CheckInAnalyticsEvent")
        request.resultType = .dictionaryResultType
        request.propertiesToGroupBy = ["step"]
        request.includesPendingChanges = false

        let countDescription = NSExpressionDescription()
        countDescription.name = "count"
        countDescription.expression = NSExpression(forFunction: "count:", arguments: [NSExpression(forKeyPath: "step")])
        countDescription.expressionResultType = .integer32AttributeType

        let predicates: [NSPredicate] = [
            NSPredicate(format: "eventType == %@", CheckInAnalyticsEventType.stepFirstInteracted.rawValue),
            NSPredicate(format: "step != nil")
        ]
        request.predicate = compoundPredicate(for: scope, additional: predicates)
        request.propertiesToFetch = ["step", countDescription]

        let rows = try context.fetch(request)
        var counts: [CheckInAnalyticsStep: Int] = [:]
        for dict in rows {
            guard let raw = dict["step"] as? String,
                  let step = CheckInAnalyticsStep(rawValue: raw),
                  let count = dict["count"] as? NSNumber else { continue }
            counts[step] = count.intValue
        }
        return counts
    }

    private func fetchDaypartCounts(scope: FetchScope, in context: NSManagedObjectContext) throws -> [Daypart: Int] {
        let request = NSFetchRequest<NSDictionary>(entityName: "CheckInAnalyticsEvent")
        request.resultType = .dictionaryResultType
        request.propertiesToGroupBy = ["daypart"]
        request.includesPendingChanges = false

        let countDescription = NSExpressionDescription()
        countDescription.name = "count"
        countDescription.expression = NSExpression(forFunction: "count:", arguments: [NSExpression(forKeyPath: "daypart")])
        countDescription.expressionResultType = .integer32AttributeType

        let predicates: [NSPredicate] = [
            NSPredicate(format: "eventType == %@", CheckInAnalyticsEventType.submitted.rawValue),
            NSPredicate(format: "daypart != nil")
        ]
        request.predicate = compoundPredicate(for: scope, additional: predicates)
        request.propertiesToFetch = ["daypart", countDescription]

        let rows = try context.fetch(request)
        var counts: [Daypart: Int] = [:]
        for dict in rows {
            guard let raw = dict["daypart"] as? String,
                  let dp = Daypart(rawValue: raw),
                  let count = dict["count"] as? NSNumber else { continue }
            counts[dp] = count.intValue
        }
        return counts
    }

    private func countSubmitted(where predicate: NSPredicate, scope: FetchScope, in context: NSManagedObjectContext) throws -> Int {
        let request = NSFetchRequest<NSNumber>(entityName: "CheckInAnalyticsEvent")
        request.resultType = .countResultType
        request.includesPendingChanges = false

        var predicates: [NSPredicate] = [
            NSPredicate(format: "eventType == %@", CheckInAnalyticsEventType.submitted.rawValue),
            predicate
        ]
        request.predicate = compoundPredicate(for: scope, additional: predicates)

        return try context.count(for: request)
    }

    private func fetchCategoryCounts(scope: FetchScope, in context: NSManagedObjectContext) throws -> (symptomCounts: [String: Int], concernCounts: [String: Int]) {
        let request = NSFetchRequest<NSDictionary>(entityName: "CheckInAnalyticsEvent")
        request.resultType = .dictionaryResultType
        request.propertiesToFetch = ["symptomCategories", "concernCategories"]
        request.fetchBatchSize = 200
        request.includesPendingChanges = false

        var predicates: [NSPredicate] = [
            NSPredicate(format: "eventType == %@", CheckInAnalyticsEventType.submitted.rawValue),
            NSPredicate(format: "symptomCategories != nil OR concernCategories != nil")
        ]
        request.predicate = compoundPredicate(for: scope, additional: predicates)

        let rows = try context.fetch(request)
        var symptomCounts: [String: Int] = [:]
        var concernCounts: [String: Int] = [:]

        func addCounts(from text: String?, into dict: inout [String: Int]) {
            for category in sanitizedCategories(from: text) {
                dict[category, default: 0] += 1
            }
        }

        for dict in rows {
            addCounts(from: dict["symptomCategories"] as? String, into: &symptomCounts)
            addCounts(from: dict["concernCategories"] as? String, into: &concernCounts)
        }

        return (symptomCounts, concernCounts)
    }

    private func sanitizedCategories(from text: String?) -> [String] {
        guard let text else { return [] }
        return text
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.count <= Constants.maxCategoryNameLength }
    }
}
