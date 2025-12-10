import Foundation

enum AdminDigestCadence: String, Codable, CaseIterable {
    case off
    case daily
    case weekly

    var displayName: String {
        switch self {
        case .off: return "Off"
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        }
    }
}

struct AdminDigestSettings: Codable, Equatable {
    var cadence: AdminDigestCadence
    /// Hour/minute for when the digest should be delivered.
    var deliveryTime: DateComponents

    var includeAtRisk: Bool
    var includeOverdue: Bool

    /// Days since last check-in before a person is considered overdue.
    var overdueDaysThreshold: Int

    /// Max people to list in each section to keep notification text short.
    var maxPeoplePerSection: Int

    static let `default` = AdminDigestSettings(
        cadence: .weekly,
        deliveryTime: {
            var comps = DateComponents()
            comps.hour = 8
            comps.minute = 0
            return comps
        }(),
        includeAtRisk: true,
        includeOverdue: true,
        overdueDaysThreshold: 7,
        maxPeoplePerSection: 4
    )
}

protocol AdminDigestSettingsStoring {
    func load() -> AdminDigestSettings
    func save(_ settings: AdminDigestSettings)
    func update(_ mutate: (inout AdminDigestSettings) -> Void) -> AdminDigestSettings
}

final class AdminDigestSettingsStore: AdminDigestSettingsStoring {
    private enum Keys {
        static let settings = "DaVita.AdminDigest.settings"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> AdminDigestSettings {
        guard
            let data = defaults.data(forKey: Keys.settings),
            let decoded = try? JSONDecoder().decode(AdminDigestSettings.self, from: data)
        else {
            return .default
        }
        return decoded
    }

    func save(_ settings: AdminDigestSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: Keys.settings)
    }

    @discardableResult
    func update(_ mutate: (inout AdminDigestSettings) -> Void) -> AdminDigestSettings {
        var settings = load()
        mutate(&settings)
        save(settings)
        return settings
    }
}


