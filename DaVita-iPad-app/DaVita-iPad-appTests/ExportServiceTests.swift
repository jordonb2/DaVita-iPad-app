import XCTest
import CoreData
@testable import DaVita_iPad_app

final class ExportServiceTests: XCTestCase {

    func testCSVExportRespectsFiltersAndWritesToTemp() throws {
        let stack = TestCoreDataStack()
        let ctx = stack.viewContext
        let repo = CheckInRepository(context: ctx)
        let service = ExportService(context: ctx)

        let person = Person(context: ctx)
        person.id = UUID()
        person.createdAt = Date()
        person.name = "Charlie"
        person.nameLowercasedValue = Person.normalizedLowercasedName(from: person.name)

        let now = Date()
        let includeDate = now
        let excludeDate = now.addingTimeInterval(-60 * 60 * 24 * 40)

        _ = repo.createRecord(createdAt: includeDate, for: person, data: PersonCheckInData(painLevel: 4, energyBucket: .high, moodBucket: .good, symptoms: "fatigue", concerns: "diet", teamNote: "note"))
        _ = repo.createRecord(createdAt: excludeDate, for: person, data: PersonCheckInData(painLevel: 2, energyBucket: .low, moodBucket: .sad, symptoms: "cough", concerns: "sleep", teamNote: "old"))

        try ctx.save()

        let start = now.addingTimeInterval(-60 * 60 * 24 * 30) // last 30 days
        let filter = CheckInHistoryFilter(startDate: start)

        let url = try service.exportCheckInsCSV(filter: filter)
        let contents = try String(contentsOf: url)

        // Header + one row
        let rows = contents.split(separator: "\r\n")
        XCTAssertEqual(rows.count, 2)
        XCTAssertTrue(url.path.contains("exports"))
    }
}

