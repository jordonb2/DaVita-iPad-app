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
        let energyBucket = EnergyBucket.from(energyLevelText: checkInData.energyLevel)?.rawValue
        let moodBucket = MoodBucket.from(moodText: checkInData.mood)?.rawValue

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

private enum EnergyBucket: Int16 {
    case low = 0
    case okay = 1
    case high = 2

    static func from(energyLevelText: String?) -> EnergyBucket? {
        guard let energyLevelText else { return nil }
        switch energyLevelText.lowercased() {
        case "low": return .low
        case "okay": return .okay
        case "high": return .high
        default: return nil
        }
    }
}

private enum MoodBucket: Int16 {
    case sad = 0
    case neutral = 1
    case good = 2

    static func from(moodText: String?) -> MoodBucket? {
        guard let moodText else { return nil }
        switch moodText.lowercased() {
        case "sad": return .sad
        case "neutral": return .neutral
        case "good": return .good
        default: return nil
        }
    }
}
