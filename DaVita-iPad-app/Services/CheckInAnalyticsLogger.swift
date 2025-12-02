import Foundation
import CoreData

enum CheckInAnalyticsEventType: String {
    case stepFirstInteracted
    case submitted
    case skipped
    case dismissed
}

enum CheckInAnalyticsStep: String {
    case pain
    case energy
    case mood
    case symptoms
    case concerns
    case teamNote
}

protocol CheckInAnalyticsLogging {
    func logStepFirstInteracted(step: CheckInAnalyticsStep)
    func logSubmitted(checkInData: PersonCheckInData, durationSeconds: Double)
    func logSkipped(durationSeconds: Double?, lastStep: CheckInAnalyticsStep?)
    func logDismissed(durationSeconds: Double?, lastStep: CheckInAnalyticsStep?)
}

final class CheckInAnalyticsLogger: CheckInAnalyticsLogging {

    private let coreDataStack: CoreDataStacking

    init(coreDataStack: CoreDataStacking) {
        self.coreDataStack = coreDataStack
    }

    func logStepFirstInteracted(step: CheckInAnalyticsStep) {
        logEvent(type: .stepFirstInteracted, step: step, durationSeconds: nil, payload: nil)
    }

    func logSubmitted(checkInData: PersonCheckInData, durationSeconds: Double) {
        let payload = Payload.from(checkInData: checkInData)
        logEvent(type: .submitted, step: nil, durationSeconds: durationSeconds, payload: payload)
    }

    func logSkipped(durationSeconds: Double?, lastStep: CheckInAnalyticsStep?) {
        logEvent(type: .skipped, step: lastStep, durationSeconds: durationSeconds, payload: nil)
    }

    func logDismissed(durationSeconds: Double?, lastStep: CheckInAnalyticsStep?) {
        logEvent(type: .dismissed, step: lastStep, durationSeconds: durationSeconds, payload: nil)
    }

    private func logEvent(type: CheckInAnalyticsEventType, step: CheckInAnalyticsStep?, durationSeconds: Double?, payload: Payload?) {
        let ctx = coreDataStack.newBackgroundContext()
        ctx.perform {
            let event = CheckInAnalyticsEvent(context: ctx)
            event.id = UUID()
            event.createdAt = Date()
            event.eventTypeEnum = type
            event.stepEnum = step
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
                if ctx.hasChanges {
                    try ctx.save()
                }
            } catch {
                AppLog.analytics.error("Analytics save error: \(error, privacy: .public)")
            }
        }
    }
}

extension CheckInAnalyticsEvent {
    var eventTypeEnum: CheckInAnalyticsEventType? {
        get { eventType.flatMap(CheckInAnalyticsEventType.init(rawValue:)) }
        set { eventType = newValue?.rawValue }
    }

    var stepEnum: CheckInAnalyticsStep? {
        get { step.flatMap(CheckInAnalyticsStep.init(rawValue:)) }
        set { step = newValue?.rawValue }
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

