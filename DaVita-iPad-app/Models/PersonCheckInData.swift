import Foundation

/// Bucketed survey responses to prevent free-text drift.
///
/// Raw values are intentionally stable for persistence.
enum EnergyBucket: Int16, CaseIterable {
    case low = 0
    case okay = 1
    case high = 2

    var displayText: String {
        switch self {
        case .low: return "Low"
        case .okay: return "Okay"
        case .high: return "High"
        }
    }

    static func from(legacyText: String?) -> EnergyBucket? {
        guard let legacyText else { return nil }
        switch legacyText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "low": return .low
        case "okay": return .okay
        case "high": return .high
        default: return nil
        }
    }
}

enum MoodBucket: Int16, CaseIterable {
    case sad = 0
    case neutral = 1
    case good = 2

    var displayText: String {
        switch self {
        case .sad: return "Sad"
        case .neutral: return "Neutral"
        case .good: return "Good"
        }
    }

    static func from(legacyText: String?) -> MoodBucket? {
        guard let legacyText else { return nil }
        switch legacyText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "sad": return .sad
        case "neutral": return .neutral
        case "good": return .good
        default: return nil
        }
    }
}

struct PersonCheckInData {
    var painLevel: Int16?

    /// Canonical bucketed values (preferred).
    var energyBucket: EnergyBucket?
    var moodBucket: MoodBucket?

    var symptoms: String?
    var concerns: String?
    var teamNote: String?

    /// Backwards-compatible computed strings for display / legacy storage.
    var energyLevelText: String? { energyBucket?.displayText }
    var moodText: String? { moodBucket?.displayText }
}

enum CheckInGuardrails {
    // Keep these intentionally conservative; we can tune based on real-world usage.
    static let maxSymptomsChars: Int = 1000
    static let maxConcernsChars: Int = 1000
    static let maxTeamNoteChars: Int = 1000

    static let painMin: Int16 = 0
    static let painMax: Int16 = 10
}

extension PersonCheckInData {
    /// Returns a validated/sanitized copy suitable for persistence.
    ///
    /// - Pain is clamped to \(CheckInGuardrails.painMin)...\(CheckInGuardrails.painMax)
    /// - Text is trimmed; empty becomes nil; strings are truncated to max lengths
    func sanitized() -> PersonCheckInData {
        var copy = self

        if let p = copy.painLevel {
            copy.painLevel = min(CheckInGuardrails.painMax, max(CheckInGuardrails.painMin, p))
        }

        copy.symptoms = sanitizeText(copy.symptoms, max: CheckInGuardrails.maxSymptomsChars)
        copy.concerns = sanitizeText(copy.concerns, max: CheckInGuardrails.maxConcernsChars)
        copy.teamNote = sanitizeText(copy.teamNote, max: CheckInGuardrails.maxTeamNoteChars)

        return copy
    }

    private func sanitizeText(_ value: String?, max: Int) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.count <= max { return trimmed }
        return String(trimmed.prefix(max))
    }

    /// Returns true if sanitization would change any field (used for logging).
    func needsSanitization() -> Bool {
        let s = sanitized()
        return s.painLevel != painLevel ||
            s.symptoms != symptoms ||
            s.concerns != concerns ||
            s.teamNote != teamNote
    }
}

