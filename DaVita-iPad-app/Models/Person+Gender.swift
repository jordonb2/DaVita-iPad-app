import Foundation

extension Person {
    /// Strongly-typed accessor for persisted `gender` string.
    ///
    /// Backwards-compatible: reads legacy values like `"Male"` and writes stable `Gender.rawValue`.
    var genderEnum: Gender? {
        get { Gender(legacy: gender) }
        set { gender = newValue?.rawValue }
    }
}


