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
        try service.writeCheckIn(personID: person.objectID, data: raw, at: Date())

        // Wait for background insert/save to complete.
        let didSave = expectation(description: "background check-in record saved")
        var token: NSObjectProtocol?
        token = NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextDidSave,
            object: nil,
            queue: nil
        ) { note in
            guard let inserts = note.userInfo?[NSInsertedObjectsKey] as? Set<NSManagedObject> else { return }
            if inserts.contains(where: { $0 is CheckInRecord }) {
                didSave.fulfill()
            }
        }

        wait(for: [didSave], timeout: 2.5)
        if let token { NotificationCenter.default.removeObserver(token) }

        let req: NSFetchRequest<CheckInRecord> = CheckInRecord.fetchRequest()
        req.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        let record = try stack.viewContext.performAndWaitThrowing {
            try stack.viewContext.fetch(req).first
        }

        XCTAssertNotNil(record)
        guard let record else { return }

        XCTAssertEqual(record.painLevel, 10) // clamped
        XCTAssertEqual(record.symptoms?.trimmingCharacters(in: .whitespacesAndNewlines), "tired")
        XCTAssertTrue((record.concerns ?? "").count <= ValidationRules.CheckIn.maxConcernsChars)
        XCTAssertNil(record.teamNote)

        // Latest fields on person should be updated too.
        let refreshedPerson = try stack.viewContext.performAndWaitThrowing {
            try stack.viewContext.existingObject(with: person.objectID) as? Person
        }
        XCTAssertEqual(refreshedPerson?.checkInPain, 10)
        XCTAssertEqual(refreshedPerson?.checkInEnergy, EnergyBucket.high.displayText)
        XCTAssertEqual(refreshedPerson?.checkInMood, MoodBucket.good.displayText)
        XCTAssertEqual(refreshedPerson?.checkInSymptoms, "tired")
        XCTAssertNil(refreshedPerson?.checkInTeamNote)
    }
}
