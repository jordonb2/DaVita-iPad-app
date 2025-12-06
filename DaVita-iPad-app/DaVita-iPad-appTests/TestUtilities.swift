import XCTest
import CoreData
@testable import DaVita_iPad_app

/// Lightweight helpers for building deterministic test data and awaiting async Core Data work.
enum TestUtilities {

    /// Creates a person in the provided context (no background threads).
    @discardableResult
    static func makePerson(
        context: NSManagedObjectContext,
        name: String = "Test Person",
        gender: Gender? = nil,
        dob: Date? = nil,
        id: UUID = UUID(),
        createdAt: Date = Date()
    ) -> Person {
        let repo = PersonRepository(context: context)
        let person = repo.createPerson(id: id, createdAt: createdAt, name: name, gender: gender, dob: dob)
        person.nameLowercasedValue = Person.normalizedLowercasedName(from: person.name)
        return person
    }

    /// Creates a check-in record for a person in the provided context.
    @discardableResult
    static func makeCheckInRecord(
        context: NSManagedObjectContext,
        person: Person,
        createdAt: Date = Date(),
        data: PersonCheckInData = PersonCheckInData(
            painLevel: 5,
            energyBucket: .okay,
            moodBucket: .neutral,
            symptoms: "symptom",
            concerns: "concern",
            teamNote: nil
        )
    ) -> CheckInRecord {
        let repo = CheckInRepository(context: context)
        return repo.createRecord(createdAt: createdAt, for: person, data: data)
    }

    /// Creates an analytics event with typed fields in the provided context.
    @discardableResult
    static func makeAnalyticsEvent(
        context: NSManagedObjectContext,
        type: CheckInAnalyticsEventType,
        createdAt: Date = Date(),
        step: CheckInAnalyticsStep? = nil,
        duration: Double? = nil,
        painBucket: CheckInAnalyticsPainBucket? = nil,
        energyBucket: EnergyBucket? = nil,
        moodBucket: MoodBucket? = nil,
        symptomCategories: [String]? = nil,
        concernCategories: [String]? = nil,
        daypart: Daypart? = nil
    ) -> CheckInAnalyticsEvent {
        let event = CheckInAnalyticsEvent(context: context)
        event.id = UUID()
        event.createdAt = createdAt
        event.eventTypeEnum = type
        event.stepEnum = step
        if let duration { event.durationSeconds = duration }
        event.painBucketEnum = painBucket
        event.energyBucketEnum = energyBucket
        event.moodBucketEnum = moodBucket
        event.symptomCategoriesList = symptomCategories
        event.concernCategoriesList = concernCategories
        event.daypartEnum = daypart ?? Daypart.from(date: createdAt)
        return event
    }

    /// Awaits a save notification from the given context (or its parents) to make async writes deterministic.
    static func waitForSave(on context: NSManagedObjectContext, timeout: TimeInterval = 2, file: StaticString = #file, line: UInt = #line) {
        let expectation = XCTestExpectation(description: "context did save")
        let token = NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextDidSave,
            object: context,
            queue: nil
        ) { _ in
            expectation.fulfill()
        }
        defer { NotificationCenter.default.removeObserver(token) }
        _ = XCTWaiter.wait(for: [expectation], timeout: timeout)
    }

    /// Runs a block with a frozen date supplied to the closure.
    static func withFrozenDate<T>(_ date: Date, execute block: (Date) throws -> T) rethrows -> T {
        try block(date)
    }
}

