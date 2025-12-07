import Foundation

/// Central source of truth for validation rules & guardrails.
///
/// Keep this file:
/// - Small and boring (constants + minimal helpers)
/// - Free of UIKit / CoreData imports (so it's usable everywhere)
enum ValidationRules {

    // MARK: - Person

    enum Person {
        /// Required field (UI should enforce a max length; persistence will truncate as a backstop).
        static let nameMaxChars: Int = 120

        /// Max date-of-birth selectable/valid (prevents "future DOB").
        static func maxDOBDate(now: Date = Date()) -> Date { now }

        static func isValidDOB(_ dob: Date, now: Date = Date()) -> Bool {
            dob <= now
        }
    }

    // MARK: - Search

    enum Search {
        static let keywordMaxChars: Int = 100
    }

    // MARK: - Gender (string payloads)

    enum Gender {
        static let maxChars: Int = 32
    }

    // MARK: - Check-in

    enum CheckIn {
        // Keep these intentionally conservative; tune based on real-world usage.
        static let maxSymptomsChars: Int = 600
        static let maxConcernsChars: Int = 600
        static let maxTeamNoteChars: Int = 600

        static let painMin: Int16 = 0
        static let painMax: Int16 = 10

        static var painRange: ClosedRange<Int16> { painMin...painMax }
    }

    // MARK: - Core Data required fields

    enum CoreData {
        /// Identity fields that must always be present on persisted entities.
        static let requiredIdentityKeys: [String] = ["id", "createdAt"]
    }

    // MARK: - Contact fields

    enum Contact {
        static let emailMaxChars: Int = 254 // RFC guideline upper bound
        static let urlMaxChars: Int = 2048  // conservative URL length cap
        static let phoneMaxChars: Int = 32
    }
}


