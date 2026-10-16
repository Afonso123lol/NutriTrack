import Foundation

nonisolated enum Greeting {
    static func text(for date: Date, name: String?) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        let base: String
        switch hour {
        case 5...11: base = "Good morning"
        case 12...17: base = "Good afternoon"
        default: base = "Good evening"
        }
        let trimmed = name?.trimmingCharacters(in: .whitespaces) ?? ""
        return trimmed.isEmpty ? base : "\(base), \(trimmed)"
    }
}
