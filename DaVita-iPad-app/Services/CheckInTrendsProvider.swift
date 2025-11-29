import Foundation
import CoreData

/// Computes per-person trend datasets from `CheckInRecord` history.
final class CheckInTrendsProvider {

    struct Point {
        let date: Date
        let value: Double
    }

    struct PersonTrends {
        /// Newest points last (chronological).
        let painSeries: [Point]

        /// Bucket distributions in the selected window.
        let energyDistribution: [EnergyBucket: Int]
        let moodDistribution: [MoodBucket: Int]

        /// For each symptom category, daily counts (chronological).
        let symptomCategoryDaily: [String: [Point]]

        /// Top symptom categories (count over window), sorted desc.
        let topSymptomCategories: [(category: String, count: Int)]

        let totalRecordsInWindow: Int
        let windowStart: Date
        let windowEnd: Date
    }

    private let context: NSManagedObjectContext
    private let calendar: Calendar

    init(context: NSManagedObjectContext = CoreDataStack.shared.viewContext,
         calendar: Calendar = .current) {
        self.context = context
        self.calendar = calendar
    }

    /// Computes trends for the given person.
    ///
    /// - Parameters:
    ///   - windowDays: lookback window in days (ending now)
    ///   - maxRecords: cap on number of records fetched (newest first)
    func computeTrends(for person: Person, windowDays: Int = 30, maxRecords: Int = 250) -> PersonTrends {
        let end = Date()
        let start = calendar.date(byAdding: .day, value: -max(1, windowDays), to: end) ?? end

        let repo = CheckInRepository(context: context)
        let filter = CheckInHistoryFilter(startDate: start, endDate: end, keyword: nil, limit: maxRecords)

        let records: [CheckInRecord]
        do {
            records = try repo.fetchHistory(for: person, filter: filter)
        } catch {
            print("Trends fetch error: \(error)")
            return PersonTrends(
                painSeries: [],
                energyDistribution: [:],
                moodDistribution: [:],
                symptomCategoryDaily: [:],
                topSymptomCategories: [],
                totalRecordsInWindow: 0,
                windowStart: start,
                windowEnd: end
            )
        }

        // Normalize order to chronological for time series.
        let chronological = records.sorted { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }

        // Pain series
        var painSeries: [Point] = []
        painSeries.reserveCapacity(chronological.count)
        for r in chronological {
            guard let date = r.createdAt else { continue }
            // painLevel may be optional in the model, but we always write it at creation time.
            let pain = Double(r.painLevel)
            painSeries.append(Point(date: date, value: pain))
        }

        // Distributions
        var energyDist: [EnergyBucket: Int] = [:]
        var moodDist: [MoodBucket: Int] = [:]

        // Symptom daily counts per category
        var symptomCountsTotal: [String: Int] = [:]
        var symptomCountsByDay: [String: [Date: Int]] = [:]

        for r in chronological {
            // Buckets
            if let b = energyBucket(from: r) {
                energyDist[b, default: 0] += 1
            }
            if let b = moodBucket(from: r) {
                moodDist[b, default: 0] += 1
            }

            // Symptoms categorization
            let categories = TextCategorizer.categorizeSymptoms(from: r.symptoms)
            guard !categories.isEmpty else { continue }

            let day = calendar.startOfDay(for: r.createdAt ?? end)
            for cat in categories {
                symptomCountsTotal[cat, default: 0] += 1
                var perDay = symptomCountsByDay[cat, default: [:]]
                perDay[day, default: 0] += 1
                symptomCountsByDay[cat] = perDay
            }
        }

        let top = symptomCountsTotal.sorted { $0.value > $1.value }.map { (category: $0.key, count: $0.value) }

        // Keep daily series only for top 5 categories (for UI performance).
        let topCategories = top.prefix(5).map { $0.category }
        var symptomCategoryDaily: [String: [Point]] = [:]
        for cat in topCategories {
            let perDay = symptomCountsByDay[cat, default: [:]]
            let sortedDays = perDay.keys.sorted()
            symptomCategoryDaily[cat] = sortedDays.map { day in
                Point(date: day, value: Double(perDay[day] ?? 0))
            }
        }

        return PersonTrends(
            painSeries: painSeries,
            energyDistribution: energyDist,
            moodDistribution: moodDist,
            symptomCategoryDaily: symptomCategoryDaily,
            topSymptomCategories: top,
            totalRecordsInWindow: records.count,
            windowStart: start,
            windowEnd: end
        )
    }

    // MARK: - Helpers

    private func energyBucket(from record: CheckInRecord) -> EnergyBucket? {
        if let n = record.value(forKey: "energyBucket") as? NSNumber {
            return EnergyBucket(rawValue: n.int16Value)
        }
        return EnergyBucket.from(legacyText: record.energyLevel)
    }

    private func moodBucket(from record: CheckInRecord) -> MoodBucket? {
        if let n = record.value(forKey: "moodBucket") as? NSNumber {
            return MoodBucket(rawValue: n.int16Value)
        }
        return MoodBucket.from(legacyText: record.mood)
    }
}
