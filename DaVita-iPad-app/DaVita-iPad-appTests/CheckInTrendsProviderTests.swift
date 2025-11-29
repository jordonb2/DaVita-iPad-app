import XCTest
import CoreData

@testable import DaVita_iPad_app

final class CheckInTrendsProviderTests: XCTestCase {

    func testComputeTrendsBuildsPainSeriesAndDistributions() throws {
        let stack = TestCoreDataStack()
        let peopleRepo = PersonRepository(context: stack.viewContext)
        let checkInRepo = CheckInRepository(context: stack.viewContext)

        let person = peopleRepo.createPerson(name: "Trend Person", gender: nil, dob: nil)

        let now = Date()
        let d1 = Calendar.current.date(byAdding: .day, value: -2, to: now)!
        let d2 = Calendar.current.date(byAdding: .day, value: -1, to: now)!
        let d3 = now

        _ = checkInRepo.createRecord(createdAt: d1, for: person, data: PersonCheckInData(painLevel: 2, energyBucket: .low, moodBucket: .sad, symptoms: "tired", concerns: nil, teamNote: nil))
        _ = checkInRepo.createRecord(createdAt: d2, for: person, data: PersonCheckInData(painLevel: 4, energyBucket: .okay, moodBucket: .neutral, symptoms: "dizzy", concerns: nil, teamNote: nil))
        _ = checkInRepo.createRecord(createdAt: d3, for: person, data: PersonCheckInData(painLevel: 6, energyBucket: .high, moodBucket: .good, symptoms: "tired and dizzy", concerns: nil, teamNote: nil))

        try stack.viewContext.performAndWaitThrowing {
            try stack.viewContext.save()
        }

        let provider = CheckInTrendsProvider(context: stack.viewContext)
        let trends = try provider.computeTrends(for: person, windowDays: 10)

        XCTAssertEqual(trends.painSeries.count, 3)
        // Chronological ordering
        XCTAssertLessThanOrEqual(trends.painSeries[0].date, trends.painSeries[1].date)
        XCTAssertLessThanOrEqual(trends.painSeries[1].date, trends.painSeries[2].date)

        XCTAssertEqual(trends.energyDistribution[.low], 1)
        XCTAssertEqual(trends.energyDistribution[.okay], 1)
        XCTAssertEqual(trends.energyDistribution[.high], 1)

        XCTAssertEqual(trends.moodDistribution[.sad], 1)
        XCTAssertEqual(trends.moodDistribution[.neutral], 1)
        XCTAssertEqual(trends.moodDistribution[.good], 1)

        // Symptoms should include fatigue + dizziness categories based on TextCategorizer keywords.
        let topCats = Set(trends.topSymptomCategories.map { $0.category })
        XCTAssertTrue(topCats.contains("fatigue") || topCats.contains("dizziness"))
    }
}
