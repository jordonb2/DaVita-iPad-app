import Foundation

enum DateDerived {
    /// Computes age in years at a given reference date.
    static func ageYears(dob: Date, now: Date = Date(), calendar: Calendar = .current) -> Int? {
        let comps = calendar.dateComponents([.year], from: dob, to: now)
        return comps.year
    }
}


