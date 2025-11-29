import XCTest
import CoreData

@testable import DaVita_iPad_app

final class CheckInServiceTests: XCTestCase {

    func testWriteCheckInSanitizesAndCreatesRecordAndUpdatesLatestFields() throws {
        let stack = TestCoreDataStack()
        let peopleRepo = PersonRepository(context: stack.viewContext)

        let person = peopleRepo.createPerson(name: "Test Person", gender: nil, dob: nil)
        try stack.viewContext.performAndWaitThrowing {
            try stack.viewContext.save()
        }

        // Over-range pain + overly long text should be sanitized.
        let longText = String(repeating: "a", count: 2000)
        let raw = PersonCheckInData(
            painLevel: 99,
            energyBucket: .high,
            moodBucket: .good,
            symptoms: "  tired  ",
            concerns: longText,
            teamNote: "\n\n" // should become nil
        )

        let service = CheckInService(coreDataStack: stack)
        try service.writeCheckIn(for: person, data: raw) {
            try stack.viewContext.performAndWaitThrowing {
                try stack.viewContext.save()
            }
        }

        // Wait for background insert to be merged.
        let exp = expectation(description: "check-in record created")
        let deadline = Date().addingTimeInterval(2.0)

        func poll() {
            stack.viewContext.perform {
                let req: NSFetchRequest<CheckInRecord> = CheckInRecord.fetchRequest()
                let count = (try? stack.viewContext.count(for: req)) ?? 0
                if count >= 1 {
                    exp.fulfill()
                } else if Date() < deadline {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        poll()
                    }
                }
            }
        }

        poll()
        wait(for: [exp], timeout: 2.5)

        let req: NSFetchRequest<CheckInRecord> = CheckInRecord.fetchRequest()
        req.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        let record = try stack.viewContext.performAndWaitThrowing {
            try stack.viewContext.fetch(req).first
        }

        XCTAssertNotNil(record)
        guard let record else { return }

        XCTAssertEqual(record.painLevel, 10) // clamped
        XCTAssertEqual(record.symptoms?.trimmingCharacters(in: .whitespacesAndNewlines), "tired")
        XCTAssertTrue((record.concerns ?? "").count <= CheckInGuardrails.maxConcernsChars)
        XCTAssertNil(record.teamNote)

        // Latest fields on person should be updated too.
        XCTAssertEqual(person.checkInPain, 10)
        XCTAssertEqual(person.checkInEnergy, EnergyBucket.high.displayText)
        XCTAssertEqual(person.checkInMood, MoodBucket.good.displayText)
        XCTAssertEqual(person.checkInSymptoms, "tired")
        XCTAssertNil(person.checkInTeamNote)
    }
}
