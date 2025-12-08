import Foundation

protocol SymptomGuidanceProviding {
    func tips(forSymptoms symptoms: [String], concerns: [String]) -> [SymptomGuidanceTip]
}

final class SymptomGuidanceProvider: SymptomGuidanceProviding {

    private let tipsLibrary: [SymptomGuidanceTip] = [
        SymptomGuidanceTip(
            id: "cramps_hydration",
            title: "Muscle cramps",
            body: "Gently stretch the cramped muscle and massage the area. Sip cool water if your care team allows fluids.",
            categories: ["cramps"]
        ),
        SymptomGuidanceTip(
            id: "nausea_small_meals",
            title: "Nausea",
            body: "Try small, bland snacks and slow, deep breaths. If vomiting, contact your care team.",
            categories: ["nausea"]
        ),
        SymptomGuidanceTip(
            id: "dizziness_sit",
            title: "Dizziness",
            body: "Sit or lie down until it passes. Stand up slowly and avoid sudden head movements.",
            categories: ["dizziness"]
        ),
        SymptomGuidanceTip(
            id: "sob_escalate",
            title: "Shortness of breath",
            body: "If you can’t catch your breath or it worsens, seek urgent help. If mild, sit upright, loosen clothing, and focus on slow exhales.",
            categories: ["shortness_of_breath"]
        ),
        SymptomGuidanceTip(
            id: "swelling_track",
            title: "Swelling",
            body: "Elevate your legs if able. Watch for rapid changes or pain and notify your care team.",
            categories: ["swelling"]
        ),
        SymptomGuidanceTip(
            id: "headache_rest",
            title: "Headache",
            body: "Rest in a dim room and hydrate if allowed. If sudden/severe or with vision changes, contact your care team.",
            categories: ["headache"]
        ),
        SymptomGuidanceTip(
            id: "access_redness",
            title: "Access site issues",
            body: "Check for redness, warmth, or drainage. Keep the site clean and dry; report any changes to your care team.",
            categories: ["access_site", "access_care"]
        ),
        SymptomGuidanceTip(
            id: "fatigue_pace",
            title: "Fatigue",
            body: "Pace activities, take short rests, and choose light meals. If rapidly worsening, notify your care team.",
            categories: ["fatigue"]
        ),
        SymptomGuidanceTip(
            id: "fever_chills",
            title: "Fever or chills",
            body: "Monitor temperature and watch for shaking chills or confusion. Contact your care team promptly.",
            categories: ["fever_chills"]
        ),
        SymptomGuidanceTip(
            id: "diet_fluids",
            title: "Diet and fluids",
            body: "Follow your renal diet and fluid limits. Spread fluid sips through the day and avoid high-salt foods.",
            categories: ["diet_fluids"]
        ),
        SymptomGuidanceTip(
            id: "medications",
            title: "Medications",
            body: "Take meds as prescribed and don’t double doses. If you missed a dose, ask your care team before adjusting.",
            categories: ["medications"]
        ),
        SymptomGuidanceTip(
            id: "emotional_support",
            title: "Emotional support",
            body: "It’s normal to feel stressed. Try slow breathing, brief walks if safe, and talk with someone you trust. Reach out to your care team if mood is worsening.",
            categories: ["emotional_support"]
        )
    ]

    func tips(forSymptoms symptoms: [String], concerns: [String]) -> [SymptomGuidanceTip] {
        let categories = Set(symptoms + concerns)
        guard !categories.isEmpty else { return [] }
        return tipsLibrary.filter { tip in
            !categories.isDisjoint(with: tip.categories)
        }
    }
}

