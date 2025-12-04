import Foundation
import CoreData

protocol CheckInAnalyticsSummaryProviding {
    func makeSummary(since startDate: Date?) throws -> CheckInAnalyticsSummaryProvider.Summary
}

final class CheckInAnalyticsSummaryProvider: CheckInAnalyticsSummaryProviding {

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

    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func makeSummary(since startDate: Date? = nil) throws -> Summary {
        let eventCounts = try fetchEventTypeCounts(since: startDate)
        let stepCounts = try fetchStepInteractionCounts(since: startDate)
        let submissionDurationsAverage = try fetchAverageDuration(for: .submitted, since: startDate)
        let skipDurationsAverage = try fetchAverageDuration(for: .skipped, since: startDate)
        let submissionsByDaypart = try fetchDaypartCounts(since: startDate)

        let highPainSubmitted = try countSubmitted(where: NSPredicate(format: "painBucket == %d", CheckInAnalyticsPainBucket.high.rawValue), since: startDate)
        let lowEnergySubmitted = try countSubmitted(where: NSPredicate(format: "energyBucket == %d", EnergyBucket.low.rawValue), since: startDate)

        let categoryCounts = try fetchCategoryCounts(since: startDate)

        let presentedCount = eventCounts[.stepFirstInteracted, default: 0] + eventCounts[.submitted, default: 0] + eventCounts[.skipped, default: 0] + eventCounts[.dismissed, default: 0]
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

    // MARK: - Aggregates

    private func fetchEventTypeCounts(since startDate: Date?) throws -> [CheckInAnalyticsEventType: Int] {
        let request = NSFetchRequest<NSDictionary>(entityName: "CheckInAnalyticsEvent")
        request.resultType = .dictionaryResultType
        request.propertiesToGroupBy = ["eventType"]

        let countDescription = NSExpressionDescription()
        countDescription.name = "count"
        countDescription.expression = NSExpression(forFunction: "count:", arguments: [NSExpression(forKeyPath: "eventType")])
        countDescription.expressionResultType = .integer32AttributeType

        request.propertiesToFetch = ["eventType", countDescription]
        if let startDate {
            request.predicate = NSPredicate(format: "createdAt >= %@", startDate as NSDate)
        }

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

    private func fetchAverageDuration(for type: CheckInAnalyticsEventType, since startDate: Date?) throws -> Double {
        let request = NSFetchRequest<NSDictionary>(entityName: "CheckInAnalyticsEvent")
        request.resultType = .dictionaryResultType

        let avgDescription = NSExpressionDescription()
        avgDescription.name = "avgDuration"
        avgDescription.expression = NSExpression(forFunction: "average:", arguments: [NSExpression(forKeyPath: "durationSeconds")])
        avgDescription.expressionResultType = .doubleAttributeType

        var predicates: [NSPredicate] = [NSPredicate(format: "eventType == %@", type.rawValue)]
        if let startDate {
            predicates.append(NSPredicate(format: "createdAt >= %@", startDate as NSDate))
        }
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        request.propertiesToFetch = [avgDescription]

        let rows = try context.fetch(request)
        let value = (rows.first?["avgDuration"] as? NSNumber)?.doubleValue ?? 0
        return value
    }

    private func fetchStepInteractionCounts(since startDate: Date?) throws -> [CheckInAnalyticsStep: Int] {
        let request = NSFetchRequest<NSDictionary>(entityName: "CheckInAnalyticsEvent")
        request.resultType = .dictionaryResultType
        request.propertiesToGroupBy = ["step"]

        let countDescription = NSExpressionDescription()
        countDescription.name = "count"
        countDescription.expression = NSExpression(forFunction: "count:", arguments: [NSExpression(forKeyPath: "step")])
        countDescription.expressionResultType = .integer32AttributeType

        var predicates: [NSPredicate] = [NSPredicate(format: "eventType == %@", CheckInAnalyticsEventType.stepFirstInteracted.rawValue)]
        if let startDate {
            predicates.append(NSPredicate(format: "createdAt >= %@", startDate as NSDate))
        }
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
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

    private func fetchDaypartCounts(since startDate: Date?) throws -> [Daypart: Int] {
        let request = NSFetchRequest<NSDictionary>(entityName: "CheckInAnalyticsEvent")
        request.resultType = .dictionaryResultType
        request.propertiesToGroupBy = ["daypart"]

        let countDescription = NSExpressionDescription()
        countDescription.name = "count"
        countDescription.expression = NSExpression(forFunction: "count:", arguments: [NSExpression(forKeyPath: "daypart")])
        countDescription.expressionResultType = .integer32AttributeType

        var predicates: [NSPredicate] = [NSPredicate(format: "eventType == %@", CheckInAnalyticsEventType.submitted.rawValue)]
        if let startDate {
            predicates.append(NSPredicate(format: "createdAt >= %@", startDate as NSDate))
        }
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
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

    private func countSubmitted(where predicate: NSPredicate, since startDate: Date?) throws -> Int {
        let request = NSFetchRequest<NSNumber>(entityName: "CheckInAnalyticsEvent")
        request.resultType = .countResultType

        var predicates: [NSPredicate] = [
            NSPredicate(format: "eventType == %@", CheckInAnalyticsEventType.submitted.rawValue),
            predicate
        ]
        if let startDate {
            predicates.append(NSPredicate(format: "createdAt >= %@", startDate as NSDate))
        }
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)

        return try context.count(for: request)
    }

    private func fetchCategoryCounts(since startDate: Date?) throws -> (symptomCounts: [String: Int], concernCounts: [String: Int]) {
        let request = NSFetchRequest<NSDictionary>(entityName: "CheckInAnalyticsEvent")
        request.resultType = .dictionaryResultType
        request.propertiesToFetch = ["symptomCategories", "concernCategories"]

        var predicates: [NSPredicate] = [NSPredicate(format: "eventType == %@", CheckInAnalyticsEventType.submitted.rawValue)]
        if let startDate {
            predicates.append(NSPredicate(format: "createdAt >= %@", startDate as NSDate))
        }
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        request.fetchBatchSize = 200

        let rows = try context.fetch(request)
        var symptomCounts: [String: Int] = [:]
        var concernCounts: [String: Int] = [:]

        func addCounts(from text: String?, into dict: inout [String: Int]) {
            guard let text else { return }
            for category in text.split(separator: ",").map({ String($0) }).filter({ !$0.isEmpty }) {
                dict[category, default: 0] += 1
            }
        }

        for dict in rows {
            addCounts(from: dict["symptomCategories"] as? String, into: &symptomCounts)
            addCounts(from: dict["concernCategories"] as? String, into: &concernCounts)
        }

        return (symptomCounts, concernCounts)
    }
}

private extension Array where Element == Double {
    var mean: Double {
        guard !isEmpty else { return 0 }
        return reduce(0, +) / Double(count)
    }
}
