import Foundation

enum Daypart: String {
    case morning
    case afternoon
    case evening
    case night

    static func from(date: Date) -> Daypart {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<12: return .morning
        case 12..<17: return .afternoon
        case 17..<22: return .evening
        default: return .night
        }
    }
}
