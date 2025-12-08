import XCTest
import CoreData

@testable import DaVita_iPad_app

final class EscalationRuleEngineTests: XCTestCase {

    func testHighPainTriggersSingleNotificationWithCooldown() throws {
        let stack = TestCoreDataStack()
        let personRepo = PersonRepository(context: stack.viewContext)
        let checkInRepo = CheckInRepository(context: stack.viewContext)

        let person = personRepo.createPerson(name: "Escalation Person", gender: nil, dob: nil)
        let now = Date()
        let data = PersonCheckInData(painLevel: 9, energyBucket: .high, moodBucket: .neutral, symptoms: nil, concerns: nil, teamNote: nil)
        _ = checkInRepo.createRecord(createdAt: now, for: person, data: data)

        try stack.viewContext.performAndWaitThrowing {
            try stack.viewContext.save()
        }

        let notifier = CapturingNotifier()
        let store = InMemoryEscalationStore()
        let engine = EscalationRuleEngine(coreDataStack: stack, notifier: notifier, stateStore: store)

        engine.handleCheckIn(personID: person.objectID, data: data, at: now)
        XCTAssertEqual(notifier.payloads.count, 1)
        XCTAssertNotNil(store.lastNotified(personID: person.id!, reason: .highPain))

        // Within cooldown window, should not send another notification.
        engine.handleCheckIn(personID: person.objectID, data: data, at: now.addingTimeInterval(60 * 60))
        XCTAssertEqual(notifier.payloads.count, 1)
    }

    func testRapidPainIncreaseEscalates() throws {
        let stack = TestCoreDataStack()
        let personRepo = PersonRepository(context: stack.viewContext)
        let checkInRepo = CheckInRepository(context: stack.viewContext)

        let person = personRepo.createPerson(name: "Trend Person", gender: nil, dob: nil)
        let now = Date()
        let d1 = Calendar.current.date(byAdding: .day, value: -2, to: now)!
        let d2 = Calendar.current.date(byAdding: .day, value: -1, to: now)!

        _ = checkInRepo.createRecord(createdAt: d1, for: person, data: PersonCheckInData(painLevel: 2, energyBucket: .low, moodBucket: .neutral, symptoms: nil, concerns: nil, teamNote: nil))
        _ = checkInRepo.createRecord(createdAt: d2, for: person, data: PersonCheckInData(painLevel: 5, energyBucket: .okay, moodBucket: .neutral, symptoms: nil, concerns: nil, teamNote: nil))
        _ = checkInRepo.createRecord(createdAt: now, for: person, data: PersonCheckInData(painLevel: 7, energyBucket: .high, moodBucket: .sad, symptoms: nil, concerns: nil, teamNote: nil))

        try stack.viewContext.performAndWaitThrowing {
            try stack.viewContext.save()
        }

        let notifier = CapturingNotifier()
        let store = InMemoryEscalationStore()
        let engine = EscalationRuleEngine(coreDataStack: stack, notifier: notifier, stateStore: store)

        engine.handleCheckIn(personID: person.objectID, data: PersonCheckInData(painLevel: 7, energyBucket: .high, moodBucket: .sad, symptoms: nil, concerns: nil, teamNote: nil), at: now)

        XCTAssertEqual(notifier.payloads.count, 1)
        XCTAssertEqual(notifier.payloads.first?.title, "Pain trending up")
        XCTAssertNotNil(store.lastNotified(personID: person.id!, reason: .rapidPain))
    }
}

private final class CapturingNotifier: EscalationNotificationScheduling {
    struct Payload {
        let title: String
        let body: String
    }

    private(set) var payloads: [Payload] = []

    func sendNotification(title: String, body: String) {
        payloads.append(Payload(title: title, body: body))
    }
}

private final class InMemoryEscalationStore: EscalationStateStoring {
    private var storage: [UUID: [EscalationRuleEngine.ReasonKind: Date]] = [:]

    func lastNotified(personID: UUID, reason: EscalationRuleEngine.ReasonKind) -> Date? {
        storage[personID]?[reason]
    }

    func markNotified(personID: UUID, reason: EscalationRuleEngine.ReasonKind, at date: Date) {
        var perPerson = storage[personID] ?? [:]
        perPerson[reason] = date
        storage[personID] = perPerson
    }
}

