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
        let events = try fetchEventRows(since: startDate)

        var presentedCount = 0
        var submittedCount = 0
        var skippedCount = 0
        var dismissedCount = 0

        var completionDurations: [Double] = []
        var skipDurations: [Double] = []

        var stepCounts: [CheckInAnalyticsStep: Int] = [:]
        var highPainSubmitted = 0
        var lowEnergySubmitted = 0
        var symptomCounts: [String: Int] = [:]
        var concernCounts: [String: Int] = [:]
        var submissionsByDaypart: [Daypart: Int] = [:]

        for row in events {
            guard let eventType = row.eventType else { continue }

            switch eventType {
            case .stepFirstInteracted:
                if let step = row.step {
                    stepCounts[step, default: 0] += 1
                }

            case .submitted:
                submittedCount += 1
                if let duration = row.durationSeconds, duration > 0 {
                    completionDurations.append(duration)
                }

                if row.painBucket == 2 { highPainSubmitted += 1 }
                if row.energyBucket == 0 { lowEnergySubmitted += 1 }

                if let symptomCategories = row.symptomCategories {
                    for category in symptomCategories.split(separator: ",").map({ String($0) }) {
                        symptomCounts[category, default: 0] += 1
                    }
                }

                if let concernCategories = row.concernCategories {
                    for category in concernCategories.split(separator: ",").map({ String($0) }) {
                        concernCounts[category, default: 0] += 1
                    }
                }

                if let daypartString = row.daypart, let dp = Daypart(rawValue: daypartString) {
                    submissionsByDaypart[dp, default: 0] += 1
                }

            case .skipped:
                skippedCount += 1
                if let duration = row.durationSeconds, duration > 0 {
                    skipDurations.append(duration)
                }

            case .dismissed:
                dismissedCount += 1

            default:
                break
            }
        }

        let totalCompletedOrSkipped = submittedCount + skippedCount + dismissedCount
        let completionRate = totalCompletedOrSkipped == 0 ? 0 : Double(submittedCount) / Double(totalCompletedOrSkipped)
        let skipRate = totalCompletedOrSkipped == 0 ? 0 : Double(skippedCount) / Double(totalCompletedOrSkipped)

        let averageCompletionSeconds = completionDurations.mean
        let averageSkipSeconds = skipDurations.mean

        let highPainRate = submittedCount == 0 ? 0 : Double(highPainSubmitted) / Double(submittedCount)
        let lowEnergyRate = submittedCount == 0 ? 0 : Double(lowEnergySubmitted) / Double(submittedCount)

        return Summary(
            totalPresented: presentedCount,
            totalSubmitted: submittedCount,
            totalSkipped: skippedCount,
            totalDismissed: dismissedCount,
            completionRate: completionRate,
            skipRate: skipRate,
            averageCompletionSeconds: averageCompletionSeconds,
            averageSkipSeconds: averageSkipSeconds,
            stepFirstInteractionCounts: stepCounts,
            highPainRate: highPainRate,
            lowEnergyRate: lowEnergyRate,
            symptomCategoryCounts: symptomCounts,
            concernCategoryCounts: concernCounts,
            submissionsByDaypart: submissionsByDaypart
        )
    }

    private struct EventRow {
        let eventType: CheckInAnalyticsEventType?
        let step: CheckInAnalyticsStep?
        let durationSeconds: Double?
        let painBucket: Int16?
        let energyBucket: Int16?
        let symptomCategories: String?
        let concernCategories: String?
        let daypart: String?
    }

    private func fetchEventRows(since startDate: Date?) throws -> [EventRow] {
        let request = NSFetchRequest<NSDictionary>(entityName: "CheckInAnalyticsEvent")
        request.resultType = .dictionaryResultType
        request.fetchBatchSize = 500
        request.propertiesToFetch = [
            "eventType",
            "step",
            "durationSeconds",
            "painBucket",
            "energyBucket",
            "symptomCategories",
            "concernCategories",
            "daypart"
        ]
        if let startDate {
            request.predicate = NSPredicate(format: "createdAt >= %@", startDate as NSDate)
        }
        do {
            let rows = try context.fetch(request)
            return rows.map { dict in
                let eventTypeRaw = dict["eventType"] as? String
                let stepRaw = dict["step"] as? String
                let duration = (dict["durationSeconds"] as? NSNumber)?.doubleValue
                let painBucket = (dict["painBucket"] as? NSNumber)?.int16Value
                let energyBucket = (dict["energyBucket"] as? NSNumber)?.int16Value

                return EventRow(
                    eventType: eventTypeRaw.flatMap(CheckInAnalyticsEventType.init(rawValue:)),
                    step: stepRaw.flatMap(CheckInAnalyticsStep.init(rawValue:)),
                    durationSeconds: duration,
                    painBucket: painBucket,
                    energyBucket: energyBucket,
                    symptomCategories: dict["symptomCategories"] as? String,
                    concernCategories: dict["concernCategories"] as? String,
                    daypart: dict["daypart"] as? String
                )
            }
        } catch {
            AppLog.analytics.error("Analytics fetch error: \(error, privacy: .private)")
            throw error
        }
    }
}

private extension Array where Element == Double {
    var mean: Double {
        guard !isEmpty else { return 0 }
        return reduce(0, +) / Double(count)
    }
}
