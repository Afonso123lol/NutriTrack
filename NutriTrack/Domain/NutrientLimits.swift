struct NutrientLimits {
    static let kcalPerMJ = 238.83
    static let postMenopauseAge = 51

    let proteinMinG: Double
    let proteinMaxG: Double
    let carbsMinG: Double
    let carbsMaxG: Double
    let fatMinG: Double
    let fatMaxG: Double
    let fiberMinG: Double
    let sodiumMaxMg: Double
    let potassium: NutrientReference
    let calcium: NutrientReference
    let iron: NutrientReference
    let zinc: NutrientReference
    let magnesium: NutrientReference
    let phosphorus: NutrientReference
    let selenium: NutrientReference
    let copper: NutrientReference
    let vitaminA: NutrientReference
    let vitaminC: NutrientReference
    let vitaminD: NutrientReference
    let vitaminE: NutrientReference
    let vitaminK: NutrientReference
    let vitaminB1: NutrientReference
    let vitaminB2: NutrientReference
    let vitaminB3: NutrientReference
    let vitaminB5: NutrientReference
    let vitaminB6: NutrientReference
    let vitaminB12: NutrientReference
    let folate: NutrientReference

    static func calculate(sex: Sex, age: Int, weightKg: Double, goal: Goal, targetCalories: Double,
                          proteinRange: ClosedRange<Double>? = nil) -> NutrientLimits {
        var proteinMin: Double
        var proteinMax: Double
        switch goal {
        case .gainMuscle:
            proteinMin = weightKg * 1.6
            proteinMax = weightKg * 2.2
        case .loseFat:
            proteinMin = weightKg * 1.6
            proteinMax = weightKg * 2.4
        case .gainWeight:
            proteinMin = weightKg * 1.4
            proteinMax = weightKg * 2.0
        case .recomp:
            proteinMin = weightKg * 1.8
            proteinMax = weightKg * 2.4
        case .maintain:
            proteinMin = weightKg * 0.8
            proteinMax = weightKg * 1.6
        }
        if let proteinRange {
            proteinMin = proteinRange.lowerBound
            proteinMax = proteinRange.upperBound
        }

        let isMale = sex == .male
        let energyMJ = targetCalories / kcalPerMJ

        let iron: NutrientReference
        if isMale || age >= postMenopauseAge {
            iron = NutrientReference(reference: 11, averageRequirement: 6, upper: 40, isUpperSafeLevel: true)
        } else {
            iron = NutrientReference(reference: 16, averageRequirement: 7, upper: 40, isUpperSafeLevel: true)
        }

        return NutrientLimits(
            proteinMinG: proteinMin, proteinMaxG: proteinMax,
            carbsMinG: 130.0, carbsMaxG: (targetCalories * 0.65) / 4.0,
            fatMinG: (targetCalories * 0.20) / 9.0, fatMaxG: (targetCalories * 0.35) / 9.0,
            fiberMinG: (targetCalories / 1000.0) * 14.0,
            sodiumMaxMg: 2000.0,
            potassium: NutrientReference(reference: 3500),
            calcium: NutrientReference(reference: age >= 25 ? 950 : 1000,
                                       averageRequirement: age >= 25 ? 750 : 860, upper: 2500),
            iron: iron,
            zinc: NutrientReference(reference: isMale ? 11 : 8, upper: 25, source: .dri),
            magnesium: NutrientReference(reference: isMale ? 350 : 300, upper: 250, upperScope: .supplementsOnly),
            phosphorus: NutrientReference(reference: 550, upper: age > 70 ? 3000 : 4000, upperSource: .dri),
            selenium: NutrientReference(reference: 70, upper: 255),
            copper: NutrientReference(reference: isMale ? 1600 : 1300, upper: 5000),
            vitaminA: NutrientReference(reference: isMale ? 750 : 650, averageRequirement: isMale ? 570 : 490,
                                        upper: 3000, upperScope: .supplementsOnly),
            vitaminC: NutrientReference(reference: isMale ? 110 : 95, averageRequirement: isMale ? 90 : 80,
                                        upper: 2000, upperSource: .dri),
            vitaminD: NutrientReference(reference: 15, upper: 100),
            vitaminE: NutrientReference(reference: isMale ? 13 : 11, upper: 300),
            vitaminK: NutrientReference(reference: 70),
            vitaminB1: NutrientReference(reference: 0.1 * energyMJ, averageRequirement: 0.072 * energyMJ),
            vitaminB2: NutrientReference(reference: 1.6, averageRequirement: 1.3),
            vitaminB3: NutrientReference(reference: 1.6 * energyMJ, averageRequirement: 1.3 * energyMJ,
                                         upper: 35, upperScope: .supplementsOnly, upperSource: .dri),
            vitaminB5: NutrientReference(reference: 5),
            vitaminB6: NutrientReference(reference: isMale ? 1.7 : 1.6, averageRequirement: isMale ? 1.5 : 1.3,
                                         upper: 12),
            vitaminB12: NutrientReference(reference: 4),
            folate: NutrientReference(reference: 330, averageRequirement: 250, upper: 1000,
                                      upperScope: .supplementsOnly)
        )
    }
}
