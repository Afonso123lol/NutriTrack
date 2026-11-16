import Foundation

nonisolated struct FoodWeek: Equatable, Sendable {
    nonisolated struct Day: Equatable, Sendable {
        let calories: Double
        let proteinG: Double
        let fiberG: Double
        let saturatedFatG: Double
        let sodiumMg: Double
        let hasLongSession: Bool
    }

    static let fiberPerThousandKcal = 14.0
    static let saturatedShareLimit = 0.10
    static let sodiumLimitMg = 2000.0

    let completeText: String
    let caloriesText: String?
    let caloriesRangeText: String?
    let proteinText: String?
    let fiberText: String?
    let saturatedText: String?
    let sodiumText: String?
    let sodiumNote: String?

    static func make(days: [Day], targetCalories: Double, targetProteinG: Double, windowDays: Int) -> FoodWeek {
        let completeText = "\(days.count) of \(windowDays) complete days"
        guard !days.isEmpty else {
            return FoodWeek(completeText: completeText, caloriesText: nil, caloriesRangeText: nil, proteinText: nil,
                            fiberText: nil, saturatedText: nil, sodiumText: nil, sodiumNote: nil)
        }
        let calories = days.map(\.calories)
        let totalCalories = calories.reduce(0, +)
        let average = totalCalories / Double(days.count)
        let reached = days.filter { $0.proteinG >= targetProteinG }.count
        let fiber = totalCalories > 0 ? days.map(\.fiberG).reduce(0, +) / (totalCalories / 1000) : nil
        let saturated = totalCalories > 0 ? days.map(\.saturatedFatG).reduce(0, +) * 9 / totalCalories : nil
        let sodiumDays = days.filter { !$0.hasLongSession }
        let longDays = days.count - sodiumDays.count
        let sodium = sodiumDays.isEmpty ? nil : sodiumDays.map(\.sodiumMg).reduce(0, +) / Double(sodiumDays.count)
        let left = longDays == 0 ? "" : "Leaves out \(longDays) \(longDays == 1 ? "day" : "days") with a session over 2 h. "
        return FoodWeek(
            completeText: completeText,
            caloriesText: "\(Int(average.rounded())) kcal a day, target \(Int(targetCalories.rounded()))",
            caloriesRangeText: "\(Int((calories.min() ?? 0).rounded())) to \(Int((calories.max() ?? 0).rounded())) kcal",
            proteinText: "Target reached on \(reached) of \(days.count) days",
            fiberText: fiber.map { "\(Int($0.rounded())) g per 1000 kcal, aim \(Int(fiberPerThousandKcal))" },
            saturatedText: saturated.map { "\(Int(($0 * 100).rounded()))% of energy, keep under \(Int(saturatedShareLimit * 100))%" },
            sodiumText: sodium.map { "\(Int($0.rounded())) mg a day, keep under \(Int(sodiumLimitMg))" },
            sodiumNote: sodium == nil ? nil : left + "Less reliable for meals described by text.")
    }
}
