import XCTest
import CoreData
@testable import DaVita_iPad_app

final class CheckInRepositoryTests: XCTestCase {

    func testFetchVisitsRespectsDateAndKeywordAndOrder() throws {
        let stack = TestCoreDataStack()
        let ctx = stack.viewContext
        let repo = CheckInRepository(context: ctx)

        let person = Person(context: ctx)
        person.id = UUID()
        person.createdAt = Date()
        person.name = "Alice"

        let now = Date()
        let older = now.addingTimeInterval(-7 * 24 * 60 * 60)

        let r1 = repo.createRecord(createdAt: now, for: person, data: PersonCheckInData(painLevel: 5, energyBucket: .high, moodBucket: .good, symptoms: "nausea", concerns: "diet", teamNote: nil))
        let r2 = repo.createRecord(createdAt: older, for: person, data: PersonCheckInData(painLevel: 2, energyBucket: .low, moodBucket: .sad, symptoms: "fatigue", concerns: "work", teamNote: nil))

        try ctx.save()

        var filter = CheckInHistoryFilter()
        filter.startDate = now.addingTimeInterval(-1 * 24 * 60 * 60)
        filter.keyword = "nausea"

        let results = try repo.fetchVisits(filter: filter)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.id, r1.id)

        // Ensure ordering newest first.
        let all = try repo.fetchVisits(filter: CheckInHistoryFilter())
        XCTAssertEqual(all.map { $0.id }, [r1.id, r2.id])
    }

    func testFetchVisitsRespectsLimitAndOffset() throws {
        let stack = TestCoreDataStack()
        let ctx = stack.viewContext
        let repo = CheckInRepository(context: ctx)

        let person = Person(context: ctx)
        person.id = UUID()
        person.createdAt = Date()
        person.name = "Bob"

        let now = Date()
        let r1 = repo.createRecord(createdAt: now, for: person, data: PersonCheckInData(painLevel: 1, energyBucket: .okay, moodBucket: .neutral, symptoms: nil, concerns: nil, teamNote: nil))
        let r2 = repo.createRecord(createdAt: now.addingTimeInterval(-60), for: person, data: PersonCheckInData(painLevel: 2, energyBucket: .low, moodBucket: .sad, symptoms: nil, concerns: nil, teamNote: nil))
        let r3 = repo.createRecord(createdAt: now.addingTimeInterval(-120), for: person, data: PersonCheckInData(painLevel: 3, energyBucket: .high, moodBucket: .good, symptoms: nil, concerns: nil, teamNote: nil))

        try ctx.save()

        var filter = CheckInHistoryFilter(limit: 2, offset: 0)
        var results = try repo.fetchVisits(filter: filter)
        XCTAssertEqual(results.map { $0.id }, [r1.id, r2.id])

        filter = CheckInHistoryFilter(limit: 2, offset: 1)
        results = try repo.fetchVisits(filter: filter)
        XCTAssertEqual(results.map { $0.id }, [r2.id, r3.id])
    }
}

