import Foundation

struct TrendSharingPreferences: Codable {
    var isEnabled: Bool
    var recipients: [String]
    var lastSentAt: Date?

    init(isEnabled: Bool = false, recipients: [String] = [], lastSentAt: Date? = nil) {
        self.isEnabled = isEnabled
        self.recipients = recipients
        self.lastSentAt = lastSentAt
    }
}

protocol TrendSharingPreferencesStoring {
    func load(personID: UUID) -> TrendSharingPreferences
    func save(_ preferences: TrendSharingPreferences, for personID: UUID)
    func markSent(for personID: UUID, at date: Date)
    func nextSendDate(for preferences: TrendSharingPreferences, now: Date) -> Date?
    func isDueForSend(_ preferences: TrendSharingPreferences, now: Date) -> Bool
    func normalizeRecipients(from text: String?) -> [String]
}

/// UserDefaults-backed storage for per-person monthly sharing preferences.
final class TrendSharingPreferencesStore: TrendSharingPreferencesStoring {
    private enum Constants {
        static let keyPrefix = "DaVita.TrendSharing."
        static let maxRecipients = 10
        static let cadenceDays = 30
    }

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let calendar: Calendar

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar
    }

    func load(personID: UUID) -> TrendSharingPreferences {
        guard
            let data = defaults.data(forKey: key(for: personID)),
            let decoded = try? decoder.decode(TrendSharingPreferences.self, from: data)
        else {
            return TrendSharingPreferences()
        }
        return sanitize(decoded)
    }

    func save(_ preferences: TrendSharingPreferences, for personID: UUID) {
        let sanitized = sanitize(preferences)
        guard let data = try? encoder.encode(sanitized) else { return }
        defaults.set(data, forKey: key(for: personID))
    }

    func markSent(for personID: UUID, at date: Date = Date()) {
        var prefs = load(personID: personID)
        prefs.lastSentAt = date
        save(prefs, for: personID)
    }

    func nextSendDate(for preferences: TrendSharingPreferences, now: Date = Date()) -> Date? {
        guard preferences.isEnabled else { return nil }
        if let last = preferences.lastSentAt {
            return calendar.date(byAdding: .day, value: Constants.cadenceDays, to: last)
        }
        return now
    }

    func isDueForSend(_ preferences: TrendSharingPreferences, now: Date = Date()) -> Bool {
        guard let next = nextSendDate(for: preferences, now: now) else { return false }
        return now >= next
    }

    func normalizeRecipients(from text: String?) -> [String] {
        guard let text else { return [] }
        let tokens = text
            .split { $0 == "," || $0 == ";" || $0 == "\n" }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        return sanitizeRecipients(tokens)
    }
}

private extension TrendSharingPreferencesStore {
    func key(for personID: UUID) -> String {
        "\(Constants.keyPrefix)\(personID.uuidString)"
    }

    func sanitize(_ prefs: TrendSharingPreferences) -> TrendSharingPreferences {
        var copy = prefs
        copy.recipients = sanitizeRecipients(prefs.recipients)
        return copy
    }

    func sanitizeRecipients(_ raw: [String]) -> [String] {
        var unique: [String] = []
        for value in raw {
            guard let email = InputSanitizer.email(value), !unique.contains(email) else { continue }
            unique.append(email)
            if unique.count >= Constants.maxRecipients { break }
        }
        return unique
    }
}

