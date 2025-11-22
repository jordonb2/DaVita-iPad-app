import Foundation

enum TextCategorizer {

    static func categorizeSymptoms(from text: String?) -> [String] {
        categorize(text: text, keywordMap: symptomKeywordMap)
    }

    static func categorizeConcerns(from text: String?) -> [String] {
        categorize(text: text, keywordMap: concernKeywordMap)
    }

    private static func categorize(text: String?, keywordMap: [String: [String]]) -> [String] {
        guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        let normalized = text.lowercased()
        var categories: [String] = []

        for (category, keywords) in keywordMap {
            if keywords.contains(where: { normalized.contains($0) }) {
                categories.append(category)
            }
        }

        if categories.isEmpty {
            categories.append("other")
        }

        return categories.sorted()
    }

    private static let symptomKeywordMap: [String: [String]] = [
        "cramps": ["cramp", "cramps", "charley horse"],
        "nausea": ["nausea", "nauseous", "vomit", "throw up"],
        "dizziness": ["dizzy", "dizziness", "lightheaded"],
        "shortness_of_breath": ["short of breath", "breathless", "can't breathe"],
        "swelling": ["swelling", "swollen", "edema", "puffy"],
        "headache": ["headache", "migraine"],
        "access_site": ["fistula", "graft", "catheter", "access", "arm pain", "needle"],
        "fatigue": ["tired", "fatigue", "exhausted", "weak"],
        "fever_chills": ["fever", "chills", "hot", "cold"]
    ]

    private static let concernKeywordMap: [String: [String]] = [
        "diet_fluids": ["diet", "food", "salt", "sodium", "fluid", "thirst", "water"],
        "medications": ["med", "meds", "medicine", "pill", "prescription"],
        "schedule_transport": ["late", "time", "schedule", "ride", "transport", "bus"],
        "access_care": ["access", "needle", "arm", "fistula", "graft", "catheter"],
        "symptoms": ["cramp", "nausea", "dizzy", "breath", "swelling", "pain"],
        "financial_insurance": ["bill", "cost", "insurance", "money"],
        "emotional_support": ["scared", "anxious", "stress", "depressed", "worried"]
    ]
}
