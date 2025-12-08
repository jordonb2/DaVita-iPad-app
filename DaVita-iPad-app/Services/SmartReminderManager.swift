import Foundation

protocol SmartReminderHandling {
    func handleCheckIn(painLevel: Int16?, at date: Date)
}

protocol SmartReminderManaging: SmartReminderHandling {
    var currentSettings: SmartReminderSettings { get }
    func updateSettings(_ mutate: @escaping (inout SmartReminderSettings) -> Void, completion: @escaping (Bool) -> Void)
}

final class SmartReminderManager: SmartReminderManaging {
    private let store: SmartReminderSettingsStoring
    private let scheduler: SmartReminderScheduling
    private let calendar: Calendar

    private(set) var currentSettings: SmartReminderSettings

    init(store: SmartReminderSettingsStoring = SmartReminderSettingsStore(),
         scheduler: SmartReminderScheduling = SmartReminderScheduler(),
         calendar: Calendar = .current) {
        self.store = store
        self.scheduler = scheduler
        self.calendar = calendar
        self.currentSettings = store.load()
    }

    func updateSettings(_ mutate: @escaping (inout SmartReminderSettings) -> Void, completion: @escaping (Bool) -> Void) {
        scheduler.requestAuthorizationIfNeeded { [weak self] granted in
            guard let self else { return }
            var updated = self.currentSettings
            mutate(&updated)
            self.currentSettings = updated
            self.store.save(updated)

            self.scheduler.cancelAll()
            if granted {
                self.scheduler.scheduleDaily(settings: updated)
            }
            completion(granted)
        }
    }

    func handleCheckIn(painLevel: Int16?, at date: Date = Date()) {
        let settings = currentSettings
        guard settings.highPainEnabled else { return }
        guard let pain = painLevel else { return }
        guard pain >= settings.highPainThreshold else { return }

        if let last = settings.lastHighPainNotificationAt {
            let cooldown = TimeInterval(settings.highPainCooldownHours * 3600)
            if date.timeIntervalSince(last) < cooldown { return }
        }

        scheduler.scheduleHighPainNudge()
        currentSettings.lastHighPainNotificationAt = date
        store.save(currentSettings)
    }
}

