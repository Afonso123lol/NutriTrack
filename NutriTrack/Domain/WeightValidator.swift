import Foundation

nonisolated enum WeightCheck: Equatable, Sendable {
    case invalid
    case needsConfirmation(percent: Double)
    case ok
}

nonisolated enum WeightValidator {
    static let range = 30.0...300.0
    static let confirmationThreshold = 0.05
    static let rangeMessage = "Enter a weight between 30 and 300 kg."

    static func parse(_ text: String) -> Double? {
        Double(text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "."))
    }

    static func check(_ weightKg: Double, last: Double?) -> WeightCheck {
        guard range.contains(weightKg) else { return .invalid }
        guard let last, last > 0 else { return .ok }
        let change = abs(weightKg - last) / last
        return change > confirmationThreshold ? .needsConfirmation(percent: change * 100) : .ok
    }

    static func confirmationMessage(weightKg: Double, percent: Double) -> String {
        String(format: "That's %.1f kg, %.0f%% from your last weigh-in. Save anyway?", weightKg, percent)
    }
}
