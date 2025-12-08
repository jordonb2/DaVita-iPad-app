import Foundation

struct SmartReminderSettings: Codable, Equatable {
    var dailyEnabled: Bool
    /// Hour/minute for daily reminder.
    var dailyTime: DateComponents?

    var highPainEnabled: Bool
    var highPainThreshold: Int
    var highPainLookbackHours: Int
    var highPainCooldownHours: Int
    var lastHighPainNotificationAt: Date?

    static let `default` = SmartReminderSettings(
        dailyEnabled: false,
        dailyTime: Calendar.current.dateComponents([.hour, .minute], from: Date()),
        highPainEnabled: false,
        highPainThreshold: 7,
        highPainLookbackHours: 24,
        highPainCooldownHours: 12,
        lastHighPainNotificationAt: nil
    )
}

protocol SmartReminderSettingsStoring {
    func load() -> SmartReminderSettings
    func save(_ settings: SmartReminderSettings)
    func update(_ mutate: (inout SmartReminderSettings) -> Void) -> SmartReminderSettings
}

final class SmartReminderSettingsStore: SmartReminderSettingsStoring {
    private enum Keys {
        static let settings = "DaVita.SmartReminders.settings"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> SmartReminderSettings {
        guard
            let data = defaults.data(forKey: Keys.settings),
            let decoded = try? JSONDecoder().decode(SmartReminderSettings.self, from: data)
        else {
            return .default
        }
        return decoded
    }

    func save(_ settings: SmartReminderSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: Keys.settings)
    }

    @discardableResult
    func update(_ mutate: (inout SmartReminderSettings) -> Void) -> SmartReminderSettings {
        var settings = load()
        mutate(&settings)
        save(settings)
        return settings
    }
}

