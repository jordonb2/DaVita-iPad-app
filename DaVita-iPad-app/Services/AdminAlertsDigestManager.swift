import Foundation
import CoreData
import UserNotifications

struct AdminAlertsDigest {
    struct Entry {
        let name: String
        let detail: String
    }

    let atRisk: [Entry]
    let overdue: [Entry]
}

protocol AdminAlertsDigestHandling: AnyObject {
    func refreshDigestSchedule(reason: String?)
}

protocol AdminAlertsDigestManaging: AdminAlertsDigestHandling {
    var currentSettings: AdminDigestSettings { get }
    func updateSettings(_ mutate: @escaping (inout AdminDigestSettings) -> Void, completion: @escaping (Bool) -> Void)
}

// MARK: - Manager

final class AdminAlertsDigestManager: AdminAlertsDigestManaging {
    private let settingsStore: AdminDigestSettingsStoring
    private let scheduler: AdminAlertsDigestScheduling
    private let provider: AdminAlertsDigestProviding
    private let queue = DispatchQueue(label: "com.davita.admin-digest", qos: .utility)

    private(set) var currentSettings: AdminDigestSettings

    init(coreDataStack: CoreDataStacking,
         settingsStore: AdminDigestSettingsStoring = AdminDigestSettingsStore(),
         scheduler: AdminAlertsDigestScheduling = AdminAlertsDigestScheduler(),
         calendar: Calendar = .current) {
        self.settingsStore = settingsStore
        self.scheduler = scheduler
        self.provider = AdminAlertsDigestProvider(coreDataStack: coreDataStack, calendar: calendar)
        self.currentSettings = settingsStore.load()
    }

    func updateSettings(_ mutate: @escaping (inout AdminDigestSettings) -> Void, completion: @escaping (Bool) -> Void) {
        scheduler.requestAuthorizationIfNeeded { [weak self] granted in
            guard let self else { return }
            if !granted {
                completion(false)
                return
            }
            self.currentSettings = self.settingsStore.update(mutate)
            self.refreshDigestSchedule(reason: "settings_updated")
            completion(true)
        }
    }

    func refreshDigestSchedule(reason: String? = nil) {
        _ = reason // keeps call sites descriptive without logging noise
        let settings = currentSettings
        guard settings.cadence != .off else {
            scheduler.cancelAll()
            return
        }

        scheduler.requestAuthorizationIfNeeded { [weak self] granted in
            guard let self else { return }
            guard granted else { return }
            let now = Date()
            queue.async {
                let digest = self.provider.buildDigest(settings: settings, now: now)
                self.scheduler.scheduleDigest(settings: settings, digest: digest, now: now)
            }
        }
    }
}

// MARK: - Provider

protocol AdminAlertsDigestProviding {
    func buildDigest(settings: AdminDigestSettings, now: Date) -> AdminAlertsDigest
}

final class AdminAlertsDigestProvider: AdminAlertsDigestProviding {
    private let coreDataStack: CoreDataStacking
    private let calendar: Calendar
    private let escalationConfig: EscalationRuleEngine.Config

    init(coreDataStack: CoreDataStacking,
         calendar: Calendar = .current,
         escalationConfig: EscalationRuleEngine.Config = .default) {
        self.coreDataStack = coreDataStack
        self.calendar = calendar
        self.escalationConfig = escalationConfig
    }

    func buildDigest(settings: AdminDigestSettings, now: Date = Date()) -> AdminAlertsDigest {
        var atRisk: [AdminAlertsDigest.Entry] = []
        var overdue: [AdminAlertsDigest.Entry] = []

        do {
            try coreDataStack.performBackgroundTaskAndWait { ctx in
                let fetch: NSFetchRequest<Person> = Person.fetchRequest()
                let people = try ctx.fetch(fetch)
                let repo = CheckInRepository(context: ctx)

                for person in people {
                    let history = (try? repo.fetchHistory(for: person, filter: CheckInHistoryFilter(limit: escalationConfig.maxHistorySamples))) ?? []
                    if settings.includeAtRisk, let reason = atRiskReason(for: history, now: now) {
                        atRisk.append(AdminAlertsDigest.Entry(name: person.name ?? "This client", detail: reason))
                    }
                    if settings.includeOverdue, let reason = overdueReason(for: history, now: now, thresholdDays: settings.overdueDaysThreshold) {
                        overdue.append(AdminAlertsDigest.Entry(name: person.name ?? "This client", detail: reason))
                    }
                }
            }
        } catch {
            AppLog.analytics.error("AdminAlertsDigestProvider error: \(error, privacy: .private)")
        }

        return AdminAlertsDigest(
            atRisk: Array(atRisk.prefix(settings.maxPeoplePerSection)),
            overdue: Array(overdue.prefix(settings.maxPeoplePerSection))
        )
    }

    private func atRiskReason(for history: [CheckInRecord], now: Date) -> String? {
        guard let latest = history.first else { return nil }
        let latestData = latestCheckInData(from: latest)

        if let pain = latestData.painLevel, pain >= escalationConfig.highPainThreshold {
            return "High pain \(pain)/10"
        }

        if let mood = latestData.moodBucket, mood.rawValue <= escalationConfig.moodEscalationThreshold.rawValue {
            return "Low mood (\(mood.displayText))"
        }

        if let rapidPain = detectRapidPainIncrease(history: history, now: now) {
            return rapidPain
        }

        if let rapidMood = detectRapidMoodDrop(history: history, now: now) {
            return rapidMood
        }

        return nil
    }

    private func overdueReason(for history: [CheckInRecord], now: Date, thresholdDays: Int) -> String? {
        guard let last = history.first?.createdAt else {
            return "No check-ins yet"
        }

        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: last), to: calendar.startOfDay(for: now)).day ?? 0
        if days >= thresholdDays {
            return "Last check-in \(days)d ago"
        }
        return nil
    }

    private func latestCheckInData(from record: CheckInRecord) -> PersonCheckInData {
        let energyBucket: EnergyBucket? = {
            if let n = record.value(forKey: "energyBucket") as? NSNumber {
                return EnergyBucket(rawValue: n.int16Value)
            }
            return EnergyBucket.from(legacyText: record.energyLevel)
        }()

        let moodBucket: MoodBucket? = {
            if let n = record.value(forKey: "moodBucket") as? NSNumber {
                return MoodBucket(rawValue: n.int16Value)
            }
            return MoodBucket.from(legacyText: record.mood)
        }()

        return PersonCheckInData(
            painLevel: record.painLevel,
            energyBucket: energyBucket,
            moodBucket: moodBucket,
            symptoms: record.symptoms,
            concerns: record.concerns,
            teamNote: record.teamNote
        )
    }

    private func detectRapidPainIncrease(history: [CheckInRecord], now: Date) -> String? {
        guard !history.isEmpty else { return nil }

        let cutoff = calendar.date(byAdding: .day, value: -escalationConfig.rapidPainLookbackDays, to: now) ?? now
        let window = history.filter { record in
            guard let createdAt = record.createdAt else { return false }
            return createdAt >= cutoff
        }

        guard window.count >= escalationConfig.minTrendSamples else { return nil }

        let chronological = window.sorted { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }
        guard let first = chronological.first, let last = chronological.last else { return nil }

        let delta = Int16(last.painLevel) - Int16(first.painLevel)
        if delta >= escalationConfig.rapidPainIncrease && Int16(last.painLevel) >= escalationConfig.rapidPainFloor {
            return "Pain up \(first.painLevel)→\(last.painLevel)"
        }
        return nil
    }

    private func detectRapidMoodDrop(history: [CheckInRecord], now: Date) -> String? {
        let cutoff = calendar.date(byAdding: .day, value: -escalationConfig.rapidMoodLookbackDays, to: now) ?? now
        let moods = history
            .filter { record in
                guard let createdAt = record.createdAt else { return false }
                return createdAt >= cutoff
            }
            .compactMap { record -> MoodBucket? in
                if let n = record.value(forKey: "moodBucket") as? NSNumber {
                    return MoodBucket(rawValue: n.int16Value)
                }
                return MoodBucket.from(legacyText: record.mood)
            }

        guard moods.count >= 2 else { return nil }

        let chronological = moods.reversed()
        guard let latestMood = chronological.last else { return nil }

        if latestMood == .sad {
            let lastTwo = Array(chronological.suffix(escalationConfig.consecutiveSadMoodCount))
            if lastTwo.count == escalationConfig.consecutiveSadMoodCount && lastTwo.allSatisfy({ $0 == .sad }) {
                return "Mood stayed Sad"
            }

            if let previous = chronological.dropLast().last, latestMood.rawValue < previous.rawValue {
                return "Mood down from \(previous.displayText)"
            }
        }

        return nil
    }
}

// MARK: - Scheduler

protocol AdminAlertsDigestScheduling {
    func requestAuthorizationIfNeeded(completion: @escaping (Bool) -> Void)
    func scheduleDigest(settings: AdminDigestSettings, digest: AdminAlertsDigest, now: Date)
    func cancelAll()
}

final class AdminAlertsDigestScheduler: NSObject, AdminAlertsDigestScheduling {
    private enum IDs {
        static let daily = "adminDigest.daily"
        static let weekly = "adminDigest.weekly"
    }

    private enum Constants {
        static let weeklyWeekday = 2 // Monday
    }

    private let center: UNUserNotificationCenter
    private let calendar: Calendar

    init(center: UNUserNotificationCenter = .current(), calendar: Calendar = .current) {
        self.center = center
        self.calendar = calendar
        super.init()
    }

    func requestAuthorizationIfNeeded(completion: @escaping (Bool) -> Void) {
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                completion(true)
            case .denied:
                completion(false)
            case .notDetermined:
                self.center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    completion(granted)
                }
            @unknown default:
                completion(false)
            }
        }
    }

    func scheduleDigest(settings: AdminDigestSettings, digest: AdminAlertsDigest, now: Date = Date()) {
        cancelAll()

        guard let triggerComponents = nextTriggerComponents(for: settings, now: now) else { return }

        let content = UNMutableNotificationContent()
        content.title = "Admin alerts digest"
        content.body = bodyText(settings: settings, digest: digest)
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: settings.cadence != .off)
        let identifier = (settings.cadence == .weekly) ? IDs.weekly : IDs.daily
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request, withCompletionHandler: nil)
    }

    func cancelAll() {
        center.removePendingNotificationRequests(withIdentifiers: [IDs.daily, IDs.weekly])
    }

    private func bodyText(settings: AdminDigestSettings, digest: AdminAlertsDigest) -> String {
        var parts: [String] = []

        if settings.includeAtRisk {
            let names = digest.atRisk.map { $0.name }
            let list = names.isEmpty ? "none" : names.joined(separator: ", ")
            parts.append("At-risk: \(digest.atRisk.count) (\(list))")
        }

        if settings.includeOverdue {
            let names = digest.overdue.map { $0.name }
            let list = names.isEmpty ? "none" : names.joined(separator: ", ")
            parts.append("Overdue: \(digest.overdue.count) (\(list))")
        }

        if parts.isEmpty {
            return "No at-risk patients or overdue follow-ups right now."
        }
        return parts.joined(separator: " • ")
    }

    private func nextTriggerComponents(for settings: AdminDigestSettings, now: Date) -> DateComponents? {
        guard let hour = settings.deliveryTime.hour, let minute = settings.deliveryTime.minute else {
            return nil
        }

        var components = DateComponents()
        components.hour = hour
        components.minute = minute

        switch settings.cadence {
        case .off:
            return nil
        case .daily:
            return components
        case .weekly:
            components.weekday = Constants.weeklyWeekday
            return components
        }
    }
}


