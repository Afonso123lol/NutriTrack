import Foundation

nonisolated struct NutritionAnalysis: Codable, Hashable, Sendable {
    var dishName: String
    var comment: String?
    var calories: Double
    var proteinG: Double
    var carbsG: Double
    var fatG: Double
    var saturatedFatG: Double
    var monounsaturatedFatG: Double? = nil
    var polyunsaturatedFatG: Double? = nil
    var transFatG: Double? = nil
    var omega3G: Double
    var fiberG: Double
    var sugarG: Double
    var sodiumMg: Double
    var potassiumMg: Double
    var calciumMg: Double
    var ironMg: Double
    var zincMg: Double
    var magnesiumMg: Double
    var phosphorusMg: Double
    var seleniumUg: Double
    var copperUg: Double
    var vitaminAUg: Double? = nil
    var vitaminCMg: Double
    var vitaminDUg: Double
    var vitaminEMg: Double
    var vitaminKUg: Double
    var vitaminB1Mg: Double
    var vitaminB2Mg: Double
    var vitaminB3Mg: Double
    var vitaminB5Mg: Double
    var vitaminB6Mg: Double
    var vitaminB12Ug: Double
    var folateUg: Double
    var alcoholG: Double? = nil
    var validationFlags: [String]? = nil

    var netCarbsG: Double { max(carbsG - fiberG, 0) }
}

nonisolated extension NutritionAnalysis {
    static let numericFields: [WritableKeyPath<NutritionAnalysis, Double>] = [
        \.calories, \.proteinG, \.carbsG, \.fatG, \.saturatedFatG, \.omega3G, \.fiberG, \.sugarG,
        \.sodiumMg, \.potassiumMg, \.calciumMg, \.ironMg, \.zincMg, \.magnesiumMg, \.phosphorusMg,
        \.seleniumUg, \.copperUg, \.vitaminCMg, \.vitaminDUg, \.vitaminEMg, \.vitaminKUg,
        \.vitaminB1Mg, \.vitaminB2Mg, \.vitaminB3Mg, \.vitaminB5Mg, \.vitaminB6Mg, \.vitaminB12Ug, \.folateUg
    ]

    static let optionalNumericFields: [WritableKeyPath<NutritionAnalysis, Double?>] = [
        \.monounsaturatedFatG, \.polyunsaturatedFatG, \.transFatG, \.vitaminAUg, \.alcoholG
    ]

    static let empty = NutritionAnalysis(
        dishName: "", calories: 0, proteinG: 0, carbsG: 0, fatG: 0, saturatedFatG: 0, omega3G: 0,
        fiberG: 0, sugarG: 0, sodiumMg: 0, potassiumMg: 0, calciumMg: 0, ironMg: 0, zincMg: 0,
        magnesiumMg: 0, phosphorusMg: 0, seleniumUg: 0, copperUg: 0, vitaminCMg: 0, vitaminDUg: 0,
        vitaminEMg: 0, vitaminKUg: 0, vitaminB1Mg: 0, vitaminB2Mg: 0, vitaminB3Mg: 0, vitaminB5Mg: 0,
        vitaminB6Mg: 0, vitaminB12Ug: 0, folateUg: 0
    )

    func scaled(by factor: Double) -> NutritionAnalysis {
        var result = self
        for field in Self.numericFields { result[keyPath: field] *= factor }
        for field in Self.optionalNumericFields {
            if let value = result[keyPath: field] { result[keyPath: field] = value * factor }
        }
        return result
    }

    static func sum(_ items: [NutritionAnalysis]) -> NutritionAnalysis {
        var total = empty
        for field in optionalNumericFields { total[keyPath: field] = 0 }
        for item in items {
            for field in numericFields { total[keyPath: field] += item[keyPath: field] }
            for field in optionalNumericFields {
                total[keyPath: field] = (total[keyPath: field] ?? 0) + (item[keyPath: field] ?? 0)
            }
        }
        return total
    }
}

nonisolated enum GeminiError: Error, LocalizedError, Sendable {
    case invalidImage
    case networkError(String)
    case parsingError(String)
    case rateLimitExceeded
    case notFood

    var errorDescription: String? {
        switch self {
        case .invalidImage: return "Could not process the image."
        case .networkError(let msg): return "Network error: \(msg)"
        case .parsingError(let msg): return "Could not parse response: \(msg)"
        case .rateLimitExceeded: return "Rate limit reached. Try again later."
        case .notFood: return "No food detected. Try again with a meal photo or a clearer description."
        }
    }
}

nonisolated struct DailySummary: Sendable {
    let calories: Double
    let proteinG: Double
    let carbsG: Double
    let fatG: Double
    let fiberG: Double
    let omega3G: Double
    let ironMg: Double
    let zincMg: Double
    let magnesiumMg: Double
    let vitaminDUg: Double
    let calciumMg: Double
    let supplementsDescription: String
}

nonisolated struct UserProfileData: Sendable {
    let goal: String
    let sex: String
    let age: Int
    let weightKg: Double
    let targetCalories: Double
    let targetProteinG: Double
    let targetCarbsG: Double
    let targetFatG: Double
}
