import XCTest
import CoreData
@testable import DaVita_iPad_app

final class CheckInAnalyticsLoggerTests: XCTestCase {

    func testLogSubmittedPersistsTypedFields() throws {
        let stack = TestCoreDataStack()
        let logger = CheckInAnalyticsLogger(coreDataStack: stack)

        let data = PersonCheckInData(
            painLevel: 9,
            energyBucket: .high,
            moodBucket: .good,
            symptoms: "pain",
            concerns: "diet",
            teamNote: nil
        )

        logger.logSubmitted(checkInData: data, durationSeconds: 12)

        let fetch: NSFetchRequest<CheckInAnalyticsEvent> = CheckInAnalyticsEvent.fetchRequest()
        let events = try stack.viewContext.fetch(fetch)
        XCTAssertEqual(events.count, 1)
        let event = try XCTUnwrap(events.first)
        XCTAssertEqual(event.eventTypeEnum, .submitted)
        XCTAssertEqual(event.painBucketEnum, .high)
        XCTAssertEqual(event.energyBucketEnum, .high)
        XCTAssertEqual(event.moodBucketEnum, .good)
        XCTAssertNotNil(event.daypartEnum)
    }
}

