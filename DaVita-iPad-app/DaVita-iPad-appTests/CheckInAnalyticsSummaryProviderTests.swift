import XCTest
import CoreData
@testable import DaVita_iPad_app

final class CheckInAnalyticsSummaryProviderTests: XCTestCase {

    func testSummaryWhenNoEventsIsEmpty() throws {
        let stack = TestCoreDataStack()
        let provider = CheckInAnalyticsSummaryProvider(context: stack.viewContext)

        let summary = try provider.makeSummary(since: nil)

        XCTAssertEqual(summary.totalPresented, 0)
        XCTAssertEqual(summary.totalSubmitted, 0)
        XCTAssertEqual(summary.totalSkipped, 0)
        XCTAssertEqual(summary.totalDismissed, 0)
        XCTAssertEqual(summary.completionRate, 0)
        XCTAssertEqual(summary.skipRate, 0)
        XCTAssertEqual(summary.averageCompletionSeconds, 0)
        XCTAssertEqual(summary.averageSkipSeconds, 0)
        XCTAssertTrue(summary.stepFirstInteractionCounts.isEmpty)
        XCTAssertTrue(summary.symptomCategoryCounts.isEmpty)
        XCTAssertTrue(summary.concernCategoryCounts.isEmpty)
        XCTAssertTrue(summary.submissionsByDaypart.isEmpty)
    }

    func testSubmittedWithoutPayloadAggregatesSafely() throws {
        let stack = TestCoreDataStack()
        let ctx = stack.viewContext
        let provider = CheckInAnalyticsSummaryProvider(context: ctx)

        try ctx.performAndWaitThrowing {
            let event = CheckInAnalyticsEvent(context: ctx)
            event.id = UUID()
            event.createdAt = Date()
            event.eventTypeEnum = .submitted
            // No payload fields set.
            try ctx.save()
        }

        let summary = try provider.makeSummary(since: nil)

        XCTAssertEqual(summary.totalSubmitted, 1)
        XCTAssertEqual(summary.totalPresented, 0)
        XCTAssertEqual(summary.totalSkipped, 0)
        XCTAssertEqual(summary.totalDismissed, 0)
        XCTAssertEqual(summary.completionRate, 1)
        XCTAssertEqual(summary.skipRate, 0)
        XCTAssertEqual(summary.highPainRate, 0)
        XCTAssertEqual(summary.lowEnergyRate, 0)
        XCTAssertTrue(summary.symptomCategoryCounts.isEmpty)
        XCTAssertTrue(summary.concernCategoryCounts.isEmpty)
        XCTAssertTrue(summary.submissionsByDaypart.isEmpty)
        XCTAssertEqual(summary.averageCompletionSeconds, 0)
    }

    func testMalformedCategoriesAndBucketsAreHandled() throws {
        let stack = TestCoreDataStack()
        let ctx = stack.viewContext
        let provider = CheckInAnalyticsSummaryProvider(context: ctx)

        try ctx.performAndWaitThrowing {
            let event = CheckInAnalyticsEvent(context: ctx)
            event.id = UUID()
            event.createdAt = Date()
            event.eventTypeEnum = .submitted
            event.durationSeconds = 5
            event.painBucketEnum = .high
            event.energyBucketEnum = .low
            // Deliberately use malformed/empty separators; split should ignore empties.
            event.symptomCategories = ",,pain,,foo"
            event.concernCategories = ",,bar,,"
            // Invalid daypart should be ignored.
            event.daypart = "invalid"
            try ctx.save()
        }

        let summary = try provider.makeSummary(since: nil)

        XCTAssertEqual(summary.totalSubmitted, 1)
        XCTAssertEqual(summary.highPainRate, 1)
        XCTAssertEqual(summary.lowEnergyRate, 1)
        XCTAssertEqual(summary.symptomCategoryCounts["pain"], 1)
        XCTAssertEqual(summary.symptomCategoryCounts["foo"], 1)
        XCTAssertEqual(summary.concernCategoryCounts["bar"], 1)
        XCTAssertTrue(summary.submissionsByDaypart.isEmpty)
        XCTAssertEqual(summary.averageCompletionSeconds, 5)
    }
}

