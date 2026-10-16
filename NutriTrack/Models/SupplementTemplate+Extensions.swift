import CoreData

extension SupplementTemplate {
    private static let fields: [(ReferenceWritableKeyPath<SupplementTemplate, Double>, WritableKeyPath<NutritionAnalysis, Double>)] = [
        (\.calories, \.calories), (\.proteinG, \.proteinG), (\.carbsG, \.carbsG), (\.fatG, \.fatG),
        (\.omega3G, \.omega3G), (\.fiberG, \.fiberG), (\.sugarG, \.sugarG),
        (\.sodiumMg, \.sodiumMg), (\.potassiumMg, \.potassiumMg), (\.calciumMg, \.calciumMg), (\.ironMg, \.ironMg),
        (\.zincMg, \.zincMg), (\.magnesiumMg, \.magnesiumMg), (\.phosphorusMg, \.phosphorusMg),
        (\.seleniumUg, \.seleniumUg), (\.copperUg, \.copperUg), (\.vitaminCMg, \.vitaminCMg),
        (\.vitaminDUg, \.vitaminDUg), (\.vitaminEMg, \.vitaminEMg), (\.vitaminKUg, \.vitaminKUg),
        (\.vitaminB1Mg, \.vitaminB1Mg), (\.vitaminB2Mg, \.vitaminB2Mg), (\.vitaminB3Mg, \.vitaminB3Mg),
        (\.vitaminB5Mg, \.vitaminB5Mg), (\.vitaminB6Mg, \.vitaminB6Mg), (\.vitaminB12Ug, \.vitaminB12Ug),
        (\.folateUg, \.folateUg)
    ]

    func nutrientsScaled(by doses: Double) -> NutritionAnalysis {
        var result = NutritionAnalysis.empty
        result.dishName = name ?? "Supplement"
        for (templateField, field) in Self.fields { result[keyPath: field] = self[keyPath: templateField] * doses }
        result.vitaminAUg = vitaminAUg * doses
        return result
    }

    func clampNutrients() {
        for (field, _) in Self.fields where !(self[keyPath: field] >= 0) { self[keyPath: field] = 0 }
        if !(vitaminAUg >= 0) { vitaminAUg = 0 }
    }
}
