import Foundation

/// Finite set of supported genders for the app UI.
///
/// Stored in Core Data as `rawValue` for stability.
enum Gender: String, CaseIterable, Codable {
    case male
    case female
    case other

    var displayText: String {
        switch self {
        case .male: return "Male"
        case .female: return "Female"
        case .other: return "Other"
        }
    }

    /// Best-effort parsing from legacy / user-entered strings.
    init?(legacy: String?) {
        guard let legacy = InputSanitizer.searchKeyword(legacy)?.lowercased() else { return nil }
        switch legacy {
        case "male", "m": self = .male
        case "female", "f": self = .female
        case "other": self = .other
        default: return nil
        }
    }

    static func fromSegmentIndex(_ index: Int) -> Gender? {
        guard index >= 0 && index < Gender.allCases.count else { return nil }
        return Gender.allCases[index]
    }
}


