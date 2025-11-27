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
