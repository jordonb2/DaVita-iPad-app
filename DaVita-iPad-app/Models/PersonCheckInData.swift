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
    /// Optional context: recent medications that could affect symptoms.
    var medicationsNote: String?
    /// Optional context: events or circumstances that could affect symptoms.
    var contextNote: String?

    /// Backwards-compatible computed strings for display / legacy storage.
    var energyLevelText: String? { energyBucket?.displayText }
    var moodText: String? { moodBucket?.displayText }
}

extension PersonCheckInData {
    /// Returns a validated/sanitized copy suitable for persistence.
    ///
    /// - Pain is clamped to \(ValidationRules.CheckIn.painMin)...\(ValidationRules.CheckIn.painMax)
    /// - Text is trimmed; empty becomes nil; strings are truncated to max lengths
    func sanitized() -> PersonCheckInData {
        var copy = self

        if let p = copy.painLevel {
            copy.painLevel = min(ValidationRules.CheckIn.painMax, max(ValidationRules.CheckIn.painMin, p))
        }

        copy.symptoms = InputSanitizer.note(copy.symptoms, max: ValidationRules.CheckIn.maxSymptomsChars)
        copy.concerns = InputSanitizer.note(copy.concerns, max: ValidationRules.CheckIn.maxConcernsChars)
        copy.teamNote = InputSanitizer.note(copy.teamNote, max: ValidationRules.CheckIn.maxTeamNoteChars)
        copy.medicationsNote = InputSanitizer.note(copy.medicationsNote, max: ValidationRules.CheckIn.maxTeamNoteChars)
        copy.contextNote = InputSanitizer.note(copy.contextNote, max: ValidationRules.CheckIn.maxTeamNoteChars)

        return copy
    }

    /// Returns true if sanitization would change any field (used for logging).
    func needsSanitization() -> Bool {
        let s = sanitized()
        return s.painLevel != painLevel ||
            s.symptoms != symptoms ||
            s.concerns != concerns ||
            s.teamNote != teamNote ||
            s.medicationsNote != medicationsNote ||
            s.contextNote != contextNote
    }
}


extension PersonCheckInData {
    /// Merges optional medication/context notes into the persisted team note for storage.
    /// This keeps schema changes minimal while preserving the added context.
    func mergedForPersistence() -> PersonCheckInData {
        var copy = self
        var lines: [String] = []
        if let team = teamNote?.trimmingCharacters(in: .whitespacesAndNewlines), !team.isEmpty {
            lines.append(team)
        }
        if let meds = medicationsNote?.trimmingCharacters(in: .whitespacesAndNewlines), !meds.isEmpty {
            lines.append("Meds: \(meds)")
        }
        if let ctx = contextNote?.trimmingCharacters(in: .whitespacesAndNewlines), !ctx.isEmpty {
            lines.append("Context: \(ctx)")
        }
        copy.teamNote = lines.isEmpty ? nil : lines.joined(separator: "\n\n")
        copy.medicationsNote = nil
        copy.contextNote = nil
        return copy
    }
}
