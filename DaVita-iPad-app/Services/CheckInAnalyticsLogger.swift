import Foundation
import CoreData

final class CheckInAnalyticsLogger {
    static let shared = CheckInAnalyticsLogger(context: CoreDataStack.shared.viewContext)

    enum EventType: String {
        case stepFirstInteracted
        case submitted
        case skipped
        case dismissed
    }

    enum Step: String {
        case pain
        case energy
        case mood
        case symptoms
        case concerns
        case teamNote
    }

    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func logStepFirstInteracted(step: Step) {
        logEvent(type: .stepFirstInteracted, step: step, durationSeconds: nil, payload: nil)
    }

    func logSubmitted(checkInData: PersonCheckInData, durationSeconds: Double) {
        let payload = Payload.from(checkInData: checkInData)
        logEvent(type: .submitted, step: nil, durationSeconds: durationSeconds, payload: payload)
    }

    func logSkipped(durationSeconds: Double?, lastStep: Step?) {
        logEvent(type: .skipped, step: lastStep, durationSeconds: durationSeconds, payload: nil)
    }

    func logDismissed(durationSeconds: Double?, lastStep: Step?) {
        logEvent(type: .dismissed, step: lastStep, durationSeconds: durationSeconds, payload: nil)
    }

    private func logEvent(type: EventType, step: Step?, durationSeconds: Double?, payload: Payload?) {
        let event = CheckInAnalyticsEvent(context: context)
        event.id = UUID()
        event.createdAt = Date()
        event.eventType = type.rawValue
        event.step = step?.rawValue
        if let durationSeconds {
            event.durationSeconds = durationSeconds
        }
        if let payload {
            if let painBucket = payload.painBucket {
                event.painBucket = painBucket
            } else {
                event.setValue(nil, forKey: "painBucket")
            }
            if let energyBucket = payload.energyBucket {
                event.energyBucket = energyBucket
            } else {
                event.setValue(nil, forKey: "energyBucket")
            }
            if let moodBucket = payload.moodBucket {
                event.moodBucket = moodBucket
            } else {
                event.setValue(nil, forKey: "moodBucket")
            }
            event.symptomCategories = payload.symptomCategories
            event.concernCategories = payload.concernCategories
        }
        event.daypart = Daypart.from(date: event.createdAt ?? Date()).rawValue

        do {
            try context.save()
        } catch {
            print("Analytics save error: \(error)")
        }
    }
}

private struct Payload {
    let painBucket: Int16?
    let energyBucket: Int16?
    let moodBucket: Int16?
    let symptomCategories: String?
    let concernCategories: String?

    static func from(checkInData: PersonCheckInData) -> Payload {
        let painBucket = PainBucket.from(painLevel: checkInData.painLevel)?.rawValue
        let energyBucket = checkInData.energyBucket?.rawValue
        let moodBucket = checkInData.moodBucket?.rawValue

        let symptomCategories = TextCategorizer.categorizeSymptoms(from: checkInData.symptoms)
        let concernCategories = TextCategorizer.categorizeConcerns(from: checkInData.concerns)

        return Payload(
            painBucket: painBucket,
            energyBucket: energyBucket,
            moodBucket: moodBucket,
            symptomCategories: symptomCategories.isEmpty ? nil : symptomCategories.joined(separator: ","),
            concernCategories: concernCategories.isEmpty ? nil : concernCategories.joined(separator: ",")
        )
    }
}

private enum PainBucket: Int16 {
    case noneOrLow = 0
    case moderate = 1
    case high = 2

    static func from(painLevel: Int16?) -> PainBucket? {
        guard let painLevel else { return nil }
        switch painLevel {
        case 0...3: return .noneOrLow
        case 4...7: return .moderate
        default: return .high
        }
    }
}

