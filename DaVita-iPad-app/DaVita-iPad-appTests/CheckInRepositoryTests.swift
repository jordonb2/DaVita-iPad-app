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
        person.nameLowercasedValue = Person.normalizedLowercasedName(from: person.name)

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
        person.nameLowercasedValue = Person.normalizedLowercasedName(from: person.name)

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

    func testMaxRecordsPerPersonFiltersLatestOnly() throws {
        let stack = TestCoreDataStack()
        let ctx = stack.viewContext
        let repo = CheckInRepository(context: ctx)

        let person = Person(context: ctx)
        person.id = UUID()
        person.createdAt = Date()
        person.name = "PerPerson"
        person.nameLowercasedValue = Person.normalizedLowercasedName(from: person.name)

        let now = Date()
        var createdIds: [UUID] = []
        for i in 0..<5 {
            let id = UUID()
            createdIds.append(id)
            _ = repo.createRecord(
                id: id,
                createdAt: now.addingTimeInterval(TimeInterval(-i * 60)),
                for: person,
                data: PersonCheckInData(painLevel: Int16(i), energyBucket: .okay, moodBucket: .neutral, symptoms: nil, concerns: nil, teamNote: nil)
            )
        }
        try ctx.save()

        let filter = CheckInHistoryFilter(maxRecordsPerPerson: 2)
        let results = try repo.fetchVisits(filter: filter)
        XCTAssertEqual(results.count, 2)
        // Should be the newest two records.
        let expected = Array(createdIds.prefix(2))
        XCTAssertEqual(results.map { $0.id }, expected)
    }
}


final class PersonRepositoryTests: XCTestCase {

    func testPeopleFRCUsesDerivedSortAndBatching() throws {
        let stack = TestCoreDataStack()
        let repo = PersonRepository(context: stack.viewContext)

        let frc = repo.makePeopleFRC(delegate: nil)
        let fetch = frc.fetchRequest

        let sorts = fetch.sortDescriptors ?? []
        XCTAssertEqual(sorts.first?.key, "nameLowercased")
        XCTAssertEqual(sorts.first?.ascending, true)
        XCTAssertEqual(sorts.dropFirst().first?.key, "createdAt")
        XCTAssertEqual(sorts.dropFirst().first?.ascending, false)
        XCTAssertEqual(fetch.fetchBatchSize, 50)
    }

    func testCreatePersonSetsLowercasedSortKey() throws {
        let stack = TestCoreDataStack()
        let repo = PersonRepository(context: stack.viewContext)

        let person = repo.createPerson(name: "  Alice Smith  ", gender: nil, dob: nil)
        XCTAssertEqual(person.nameLowercasedValue, "alice smith")
    }
}
