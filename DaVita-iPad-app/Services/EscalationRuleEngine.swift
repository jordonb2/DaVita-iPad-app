import Foundation
import CoreData
import UserNotifications

protocol EscalationHandling: AnyObject {
    func handleCheckIn(personID: NSManagedObjectID, data: PersonCheckInData, at date: Date)
}

protocol EscalationNotificationScheduling {
    func sendNotification(title: String, body: String)
}

protocol EscalationStateStoring {
    func lastNotified(personID: UUID, reason: EscalationRuleEngine.ReasonKind) -> Date?
    func markNotified(personID: UUID, reason: EscalationRuleEngine.ReasonKind, at date: Date)
}

/// Evaluates pain/mood thresholds and trend deterioration, then notifies admins.
final class EscalationRuleEngine: EscalationHandling {

    enum ReasonKind: String, CaseIterable {
        case highPain
        case lowMood
        case rapidPain
        case rapidMood
    }

    struct Config {
        let highPainThreshold: Int16
        let moodEscalationThreshold: MoodBucket
        let rapidPainLookbackDays: Int
        let rapidPainIncrease: Int16
        let rapidPainFloor: Int16
        let rapidMoodLookbackDays: Int
        let minTrendSamples: Int
        let notificationCooldownHours: Int
        let consecutiveSadMoodCount: Int
        let maxHistorySamples: Int

        static let `default` = Config(
            highPainThreshold: 8,
            moodEscalationThreshold: .sad,
            rapidPainLookbackDays: 3,
            rapidPainIncrease: 3,
            rapidPainFloor: 6,
            rapidMoodLookbackDays: 5,
            minTrendSamples: 3,
            notificationCooldownHours: 12,
            consecutiveSadMoodCount: 2,
            maxHistorySamples: 15
        )
    }

    fileprivate enum Detection {
        case highPain(Int16)
        case lowMood(MoodBucket)
        case rapidPainIncrease(Int16, Int16)
        case rapidMoodDrop(MoodBucket?)

        var kind: ReasonKind {
            switch self {
            case .highPain: return .highPain
            case .lowMood: return .lowMood
            case .rapidPainIncrease: return .rapidPain
            case .rapidMoodDrop: return .rapidMood
            }
        }
    }

    private let coreDataStack: CoreDataStacking
    private let notifier: EscalationNotificationScheduling
    private let stateStore: EscalationStateStoring
    private let calendar: Calendar
    private let config: Config

    init(coreDataStack: CoreDataStacking,
         notifier: EscalationNotificationScheduling = EscalationNotificationScheduler(),
         stateStore: EscalationStateStoring = EscalationStateStore(),
         calendar: Calendar = .current,
         config: Config = .default) {
        self.coreDataStack = coreDataStack
        self.notifier = notifier
        self.stateStore = stateStore
        self.calendar = calendar
        self.config = config
    }

    func handleCheckIn(personID: NSManagedObjectID, data: PersonCheckInData, at date: Date = Date()) {
        let sanitized = data.sanitized()

        do {
            try coreDataStack.performBackgroundTaskAndWait { ctx in
                guard let person = try ctx.existingObject(with: personID) as? Person else {
                    AppLog.analytics.error("EscalationRuleEngine: Person not found for objectID")
                    return
                }

                let repo = CheckInRepository(context: ctx)
                let filter = CheckInHistoryFilter(limit: config.maxHistorySamples)
                let history = (try? repo.fetchHistory(for: person, filter: filter)) ?? []

                guard let detection = detectEscalation(latestData: sanitized, history: history, now: date) else {
                    return
                }

                guard let personUUID = person.id else {
                    AppLog.analytics.error("EscalationRuleEngine: missing person.id for escalation")
                    return
                }

                guard shouldNotify(personID: personUUID, reason: detection.kind, now: date) else { return }

                let message = notificationMessage(for: detection, personName: person.name)
                notifier.sendNotification(title: message.title, body: message.body)
                stateStore.markNotified(personID: personUUID, reason: detection.kind, at: date)
                AppLog.analytics.warning("escalation_notified reason=\(detection.kind.rawValue, privacy: .public) person=\(AppLog.Redact.pii(person.name))")
            }
        } catch {
            AppLog.analytics.error("EscalationRuleEngine error: \(error, privacy: .private)")
        }
    }
}

// MARK: - Detection
private extension EscalationRuleEngine {
    private func detectEscalation(latestData: PersonCheckInData,
                          history: [CheckInRecord],
                          now: Date) -> Detection? {
        if let pain = latestData.painLevel, pain >= config.highPainThreshold {
            return .highPain(pain)
        }

        if let mood = latestData.moodBucket, mood.rawValue <= config.moodEscalationThreshold.rawValue {
            return .lowMood(mood)
        }

        if let rapidPain = detectRapidPainIncrease(history: history, now: now) {
            return rapidPain
        }

        if let rapidMood = detectRapidMoodDrop(history: history, now: now) {
            return rapidMood
        }

        return nil
    }

    private func detectRapidPainIncrease(history: [CheckInRecord], now: Date) -> Detection? {
        guard !history.isEmpty else { return nil }

        let cutoff = calendar.date(byAdding: .day, value: -config.rapidPainLookbackDays, to: now) ?? now
        let window = history.filter { record in
            guard let createdAt = record.createdAt else { return false }
            return createdAt >= cutoff
        }

        guard window.count >= config.minTrendSamples else { return nil }

        let chronological = window.sorted { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }
        guard let first = chronological.first, let last = chronological.last else { return nil }

        let delta = Int16(last.painLevel) - Int16(first.painLevel)
        if delta >= config.rapidPainIncrease && Int16(last.painLevel) >= config.rapidPainFloor {
            return .rapidPainIncrease(Int16(first.painLevel), Int16(last.painLevel))
        }
        return nil
    }

    private func detectRapidMoodDrop(history: [CheckInRecord], now: Date) -> Detection? {
        let cutoff = calendar.date(byAdding: .day, value: -config.rapidMoodLookbackDays, to: now) ?? now
        let moods = history
            .filter { record in
                guard let createdAt = record.createdAt else { return false }
                return createdAt >= cutoff
            }
            .compactMap { moodBucket(from: $0) }

        guard moods.count >= 2 else { return nil }

        let chronological = moods.reversed()
        guard let latestMood = chronological.last else { return nil }

        if latestMood == .sad {
            let lastTwo = Array(chronological.suffix(config.consecutiveSadMoodCount))
            if lastTwo.count == config.consecutiveSadMoodCount && lastTwo.allSatisfy({ $0 == .sad }) {
                return .rapidMoodDrop(chronological.dropLast().last)
            }

            if let previous = chronological.dropLast().last, latestMood.rawValue < previous.rawValue {
                return .rapidMoodDrop(previous)
            }
        }

        return nil
    }

    private func moodBucket(from record: CheckInRecord) -> MoodBucket? {
        if let n = record.value(forKey: "moodBucket") as? NSNumber {
            return MoodBucket(rawValue: n.int16Value)
        }
        return MoodBucket.from(legacyText: record.mood)
    }
}

// MARK: - Notifications + cooldown
private extension EscalationRuleEngine {
    func shouldNotify(personID: UUID, reason: ReasonKind, now: Date) -> Bool {
        guard let last = stateStore.lastNotified(personID: personID, reason: reason) else {
            return true
        }
        let cooldownSeconds = TimeInterval(config.notificationCooldownHours * 3600)
        return now.timeIntervalSince(last) >= cooldownSeconds
    }

    func notificationMessage(for detection: Detection, personName: String?) -> (title: String, body: String) {
        let name = personName ?? "this client"

        switch detection {
        case .highPain(let pain):
            return (
                title: "High pain alert",
                body: "\(name) reported pain \(pain)/10. Notify an admin to follow up."
            )
        case .lowMood(let mood):
            return (
                title: "Low mood alert",
                body: "\(name) reported mood \"\(mood.displayText)\". Consider proactive outreach."
            )
        case .rapidPainIncrease(let start, let end):
            return (
                title: "Pain trending up",
                body: "\(name)'s pain climbed from \(start)/10 to \(end)/10 in the last few days."
            )
        case .rapidMoodDrop(let previous):
            let previousText = previous?.displayText ?? "recent days"
            return (
                title: "Mood worsening quickly",
                body: "\(name)'s mood dropped to Sad from \(previousText). Review their check-ins."
            )
        }
    }
}

// MARK: - Persistence
final class EscalationStateStore: EscalationStateStoring {
    private enum Keys {
        static let lastNotified = "DaVita.Escalation.lastNotified"
    }

    private let defaults: UserDefaults
    private let queue = DispatchQueue(label: "com.davita.escalation.state", qos: .utility)

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func lastNotified(personID: UUID, reason: EscalationRuleEngine.ReasonKind) -> Date? {
        queue.sync {
            guard let raw = defaults.dictionary(forKey: Keys.lastNotified) as? [String: TimeInterval] else {
                return nil
            }
            let key = storageKey(personID: personID, reason: reason)
            guard let ts = raw[key] else { return nil }
            return Date(timeIntervalSince1970: ts)
        }
    }

    func markNotified(personID: UUID, reason: EscalationRuleEngine.ReasonKind, at date: Date) {
        queue.sync {
            var raw = defaults.dictionary(forKey: Keys.lastNotified) as? [String: TimeInterval] ?? [:]
            raw[storageKey(personID: personID, reason: reason)] = date.timeIntervalSince1970
            defaults.set(raw, forKey: Keys.lastNotified)
        }
    }

    private func storageKey(personID: UUID, reason: EscalationRuleEngine.ReasonKind) -> String {
        "\(personID.uuidString)|\(reason.rawValue)"
    }
}

// MARK: - Notifications
final class EscalationNotificationScheduler: EscalationNotificationScheduling {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func sendNotification(title: String, body: String) {
        center.getNotificationSettings { [weak self] settings in
            guard let self else { return }
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                self.schedule(title: title, body: body)
            case .notDetermined:
                self.center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    if granted {
                        self.schedule(title: title, body: body)
                    }
                }
            case .denied:
                AppLog.analytics.warning("Escalation notifications denied by user")
            @unknown default:
                break
            }
        }
    }

    private func schedule(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // deliver immediately
        )
        center.add(request, withCompletionHandler: nil)
    }
}

