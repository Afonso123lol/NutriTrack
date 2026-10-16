import Foundation

nonisolated enum MealEditor {
    static let multiplierRange = 0.1...10.0
    static let maxNameLength = 120
    private static let editTolerance = 0.05

    static func multiplier(from text: String) -> Double? {
        let cleaned = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        guard let value = Double(cleaned), multiplierRange.contains(value) else { return nil }
        return value
    }

    static func scaled(_ analysis: NutritionAnalysis, by multiplier: Double) -> NutritionAnalysis {
        NutrientValidator.validate(analysis.scaled(by: multiplier), keepCalories: true)
    }

    static func edited(_ original: NutritionAnalysis, dishName: String, calories: Double, proteinG: Double,
                       carbsG: Double, fatG: Double, alcoholG: Double) -> NutritionAnalysis {
        var result = original
        let name = dishName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty { result.dishName = String(name.prefix(maxNameLength)) }

        let caloriesTyped = differs(calories, original.calories)
        let macrosChanged = differs(proteinG, original.proteinG) || differs(carbsG, original.carbsG)
            || differs(fatG, original.fatG) || differs(alcoholG, original.alcoholG ?? 0)
        guard caloriesTyped || macrosChanged else {
            return NutrientValidator.validate(result, keepCalories: true)
        }

        result.proteinG = proteinG
        result.carbsG = carbsG
        result.fatG = fatG
        result.alcoholG = alcoholG
        if caloriesTyped { result.calories = calories }

        var clean = NutrientValidator.validate(result, keepCalories: true)
        if !caloriesTyped {
            let fromMacros = clean.proteinG * 4 + clean.carbsG * 4 + clean.fatG * 9 + (clean.alcoholG ?? 0) * 7
            clean.calories = min(fromMacros.rounded(), NutrientValidator.maxCaloriesPerMeal)
        }
        return clean
    }

    private static func differs(_ a: Double, _ b: Double) -> Bool {
        !(abs(a - b) <= editTolerance)
    }
}
