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

enum CheckInAnalyticsPainBucket: Int16 {
    case noneOrLow = 0
    case moderate = 1
    case high = 2

    static func from(painLevel: Int16?) -> CheckInAnalyticsPainBucket? {
        guard let painLevel else { return nil }
        switch painLevel {
        case 0...3: return .noneOrLow
        case 4...7: return .moderate
        default: return .high
        }
    }
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
                event.painBucketEnum = payload.painBucket
                event.energyBucketEnum = payload.energyBucket
                event.moodBucketEnum = payload.moodBucket
                event.symptomCategoriesList = payload.symptomCategories
                event.concernCategoriesList = payload.concernCategories
            }
            event.daypartEnum = Daypart.from(date: event.createdAt ?? Date())

#if DEBUG
            assert(event.id != nil && event.createdAt != nil, "CheckInAnalyticsEvent must have id + createdAt at creation time")
#endif

            do {
                if ctx.hasChanges {
                    try ctx.save()
                }
            } catch {
                AppLog.analytics.error("Analytics save error: \(error, privacy: .private)")
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

    var painBucketEnum: CheckInAnalyticsPainBucket? {
        get {
            guard let number = value(forKey: "painBucket") as? NSNumber else { return nil }
            return CheckInAnalyticsPainBucket(rawValue: number.int16Value)
        }
        set {
            if let v = newValue {
                painBucket = v.rawValue
            } else {
                setValue(nil, forKey: "painBucket")
            }
        }
    }

    var energyBucketEnum: EnergyBucket? {
        get {
            guard let number = value(forKey: "energyBucket") as? NSNumber else { return nil }
            return EnergyBucket(rawValue: number.int16Value)
        }
        set {
            if let v = newValue {
                energyBucket = v.rawValue
            } else {
                setValue(nil, forKey: "energyBucket")
            }
        }
    }

    var moodBucketEnum: MoodBucket? {
        get {
            guard let number = value(forKey: "moodBucket") as? NSNumber else { return nil }
            return MoodBucket(rawValue: number.int16Value)
        }
        set {
            if let v = newValue {
                moodBucket = v.rawValue
            } else {
                setValue(nil, forKey: "moodBucket")
            }
        }
    }

    var daypartEnum: Daypart? {
        get { daypart.flatMap(Daypart.init(rawValue:)) }
        set { daypart = newValue?.rawValue }
    }

    var symptomCategoriesList: [String]? {
        get {
            guard let text = symptomCategories else { return nil }
            let list = text.split(separator: ",").map { String($0) }
            return list.isEmpty ? nil : list
        }
        set {
            if let list = newValue, !list.isEmpty {
                symptomCategories = list.joined(separator: ",")
            } else {
                symptomCategories = nil
            }
        }
    }

    var concernCategoriesList: [String]? {
        get {
            guard let text = concernCategories else { return nil }
            let list = text.split(separator: ",").map { String($0) }
            return list.isEmpty ? nil : list
        }
        set {
            if let list = newValue, !list.isEmpty {
                concernCategories = list.joined(separator: ",")
            } else {
                concernCategories = nil
            }
        }
    }
}


private struct Payload {
    let painBucket: CheckInAnalyticsPainBucket?
    let energyBucket: EnergyBucket?
    let moodBucket: MoodBucket?
    let symptomCategories: [String]?
    let concernCategories: [String]?

    static func from(checkInData: PersonCheckInData) -> Payload {
        let painBucket = CheckInAnalyticsPainBucket.from(painLevel: checkInData.painLevel)
        let energyBucket = checkInData.energyBucket
        let moodBucket = checkInData.moodBucket

        let symptomCategories = TextCategorizer.categorizeSymptoms(from: checkInData.symptoms)
        let concernCategories = TextCategorizer.categorizeConcerns(from: checkInData.concerns)

        return Payload(
            painBucket: painBucket,
            energyBucket: energyBucket,
            moodBucket: moodBucket,
            symptomCategories: symptomCategories.isEmpty ? nil : symptomCategories,
            concernCategories: concernCategories.isEmpty ? nil : concernCategories
        )
    }
}

