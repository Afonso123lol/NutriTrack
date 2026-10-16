import Foundation

nonisolated enum NutrientValidator {
    static let alcoholNotice = "Alcohol grams are a rough estimate and are often wrong when a meal has more than one item. Check the value before saving."

    static let calorieTolerancePercent = 0.05
    static let maxCaloriesPerMeal = 6500.0

    private static let perMealUpperBounds: [(WritableKeyPath<NutritionAnalysis, Double>, Double, String)] = [
        (\.proteinG, 300, "Protein"),
        (\.carbsG, 600, "Carbs"),
        (\.fatG, 300, "Fat"),
        (\.omega3G, 15, "Omega-3"),
        (\.fiberG, 100, "Fiber"),
        (\.sodiumMg, 8000, "Sodium"),
        (\.potassiumMg, 5000, "Potassium"),
        (\.calciumMg, 3000, "Calcium"),
        (\.ironMg, 100, "Iron"),
        (\.zincMg, 100, "Zinc"),
        (\.magnesiumMg, 800, "Magnesium"),
        (\.phosphorusMg, 3000, "Phosphorus"),
        (\.seleniumUg, 2000, "Selenium"),
        (\.copperUg, 20000, "Copper"),
        (\.vitaminCMg, 1000, "Vitamin C"),
        (\.vitaminDUg, 250, "Vitamin D"),
        (\.vitaminEMg, 100, "Vitamin E"),
        (\.vitaminKUg, 1000, "Vitamin K"),
        (\.vitaminB1Mg, 10, "Vitamin B1"),
        (\.vitaminB2Mg, 10, "Vitamin B2"),
        (\.vitaminB3Mg, 100, "Vitamin B3"),
        (\.vitaminB5Mg, 50, "Vitamin B5"),
        (\.vitaminB6Mg, 25, "Vitamin B6"),
        (\.vitaminB12Ug, 100, "Vitamin B12"),
        (\.folateUg, 2000, "Folate")
    ]

    private static let requiredFields: [WritableKeyPath<NutritionAnalysis, Double>] =
        perMealUpperBounds.map(\.0) + [\.calories, \.saturatedFatG, \.sugarG]
    private static let optionalFields: [WritableKeyPath<NutritionAnalysis, Double?>] =
        [\.monounsaturatedFatG, \.polyunsaturatedFatG, \.transFatG, \.vitaminAUg, \.alcoholG]

    static func validate(_ analysis: NutritionAnalysis, keepCalories: Bool = false) -> NutritionAnalysis {
        var a = analysis
        var flags: [String] = []

        for keyPath in requiredFields where !(a[keyPath: keyPath] >= 0) {
            a[keyPath: keyPath] = 0
        }
        for keyPath in optionalFields {
            if let value = a[keyPath: keyPath], !(value >= 0) { a[keyPath: keyPath] = 0 }
        }

        for (keyPath, bound, name) in perMealUpperBounds where a[keyPath: keyPath] > bound {
            a[keyPath: keyPath] = bound
            flags.append("\(name) capped at plausible per-meal maximum")
        }
        if let vitA = a.vitaminAUg, vitA > 10000 {
            a.vitaminAUg = 10000
            flags.append("Vitamin A capped at plausible per-meal maximum")
        }
        if a.sugarG > a.carbsG {
            a.sugarG = a.carbsG
            flags.append("Sugar capped at total carbs")
        }
        if a.fiberG > a.carbsG {
            a.fiberG = a.carbsG
            flags.append("Fiber capped at total carbs")
        }
        if a.saturatedFatG > a.fatG {
            a.saturatedFatG = a.fatG
            flags.append("Saturated fat capped at total fat")
        }
        if let trans = a.transFatG, trans > 10 {
            a.transFatG = 10
            flags.append("Trans fat capped at plausible per-meal maximum")
        }
        if let alcohol = a.alcoholG, alcohol > 150 {
            a.alcoholG = 150
            flags.append("Alcohol capped at plausible per-meal maximum")
        }

        let fatSplit = a.saturatedFatG + (a.monounsaturatedFatG ?? 0)
            + (a.polyunsaturatedFatG ?? 0) + (a.transFatG ?? 0)
        if fatSplit > a.fatG * 1.05, fatSplit > 0 {
            let scale = a.fatG / fatSplit
            a.saturatedFatG *= scale
            if let m = a.monounsaturatedFatG { a.monounsaturatedFatG = m * scale }
            if let p = a.polyunsaturatedFatG { a.polyunsaturatedFatG = p * scale }
            if let t = a.transFatG { a.transFatG = t * scale }
            flags.append("Fat breakdown scaled to match total fat")
        }

        let computedCalories = a.proteinG * 4 + a.carbsG * 4 + a.fatG * 9 + (a.alcoholG ?? 0) * 7
        if !keepCalories, computedCalories > 0 {
            let deviation = abs(a.calories - computedCalories) / computedCalories
            if deviation > calorieTolerancePercent {
                a.calories = computedCalories.rounded()
                flags.append("Calories recalculated from macros (4-4-9 rule)")
            }
        }
        if a.calories > maxCaloriesPerMeal {
            a.calories = maxCaloriesPerMeal
            flags.append("Calories capped at plausible per-meal maximum")
        }

        let microSum = a.sodiumMg + a.potassiumMg + a.calciumMg + a.ironMg + a.zincMg
            + a.magnesiumMg + a.phosphorusMg + a.seleniumUg + a.vitaminCMg + a.vitaminB12Ug
        if microSum == 0, a.calories > 50 {
            flags.append("Micronutrient data missing from analysis — values unreliable")
        }

        if (a.alcoholG ?? 0) > 0 {
            flags.append(alcoholNotice)
        }

        a.validationFlags = flags.isEmpty ? nil : flags
        return a
    }
}
