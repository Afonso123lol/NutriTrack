import Foundation

nonisolated struct RateOption: Equatable, Sendable {
    let defaultPercent: Double
    let maximumPercent: Double
}

nonisolated struct TargetInput: Sendable {
    let sex: Sex
    let age: Int
    let weightKg: Double
    let heightCm: Double
    let direction: GoalDirection
    let ratePercent: Double
    let tdee: Double
    var highProtein = false
}

nonisolated enum TargetLimit: String, Equatable, Sendable {
    case none
    case deficitShare
    case fatMass
    case absoluteRate
    case calorieFloor
    case surplusShare
    case blocked
}

nonisolated struct DeficitCap: Equatable, Sendable {
    let kcal: Double
    let limit: TargetLimit
}

nonisolated enum TargetSafeguard: Equatable, Sendable {
    case none
    case raise
    case maintenance
}

nonisolated struct PlannedTargets: Equatable, Sendable {
    let calories: Double
    let proteinG: Double
    let fatG: Double
    let carbsG: Double
    let proteinFloorG: Double
    let proteinCapG: Double
    let fatFloorG: Double
    let direction: GoalDirection
    let ratePercent: Double
    let limitedBy: TargetLimit
}

nonisolated enum TargetPlanner {
    static let energyPerKg = 7700.0
    static let maximumWeeklyLossKg = 1.5
    static let maximumWeeklyChange = 150.0
    static let carbFloorG = 130.0
    static let minimumAge = 18
    static let hardEffortRPE = 5

    static func rateOption(direction: GoalDirection, bmi: Double) -> RateOption? {
        switch direction {
        case .maintain:
            return nil
        case .lose:
            if bmi < 18.5 { return nil }
            if bmi < 25 { return RateOption(defaultPercent: 0.35, maximumPercent: 0.5) }
            if bmi < 30 { return RateOption(defaultPercent: 0.5, maximumPercent: 0.75) }
            return RateOption(defaultPercent: 0.5, maximumPercent: 1.0)
        case .gain:
            return bmi < 25 ? RateOption(defaultPercent: 0.25, maximumPercent: 0.5) : nil
        }
    }

    static func deficitCap(tdee: Double, bmi: Double, fatMassKg: Double) -> DeficitCap {
        let caps = [
            DeficitCap(kcal: tdee * (bmi >= 30 ? 0.30 : 0.25), limit: .deficitShare),
            DeficitCap(kcal: 69 * max(fatMassKg, 0), limit: .fatMass),
            DeficitCap(kcal: maximumWeeklyLossKg * energyPerKg / 7, limit: .absoluteRate)
        ]
        return caps.min { $0.kcal < $1.kcal } ?? caps[0]
    }

    static func plan(_ input: TargetInput, calories override: Double? = nil) -> PlannedTargets {
        let bmi = BodyMetrics.bmi(weightKg: input.weightKg, heightCm: input.heightCm)
        let reference = BodyMetrics.referenceWeight(weightKg: input.weightKg, heightCm: input.heightCm)
        let fatFree = BodyMetrics.fatFreeMass(sex: input.sex, weightKg: input.weightKg, heightCm: input.heightCm)

        var direction = input.direction
        var limit = TargetLimit.none
        var option = rateOption(direction: direction, bmi: bmi)
        if direction != .maintain, option == nil || (direction == .lose && input.age < minimumAge) {
            direction = .maintain
            limit = .blocked
            option = nil
        }

        var calories = input.tdee
        if let option {
            let percent = input.ratePercent > 0 ? min(input.ratePercent, option.maximumPercent) : option.defaultPercent
            let change = percent / 100 * input.weightKg * energyPerKg / 7
            if direction == .lose {
                let cap = deficitCap(tdee: input.tdee, bmi: bmi, fatMassKg: input.weightKg - fatFree)
                if change > cap.kcal { limit = cap.limit }
                calories = input.tdee - min(change, cap.kcal)
            } else {
                let cap = input.tdee * 0.15
                if change > cap { limit = .surplusShare }
                calories = input.tdee + min(change, cap)
            }
        }

        let proteinFloor = max(1.5 * fatFree, 1.2 * reference)
        let sexFloor = input.sex == .male ? 1500.0 : 1200.0
        let macroFloor = proteinFloor * 4 + 0.5 * reference * 9 + carbFloorG * 4
        let floor = max(sexFloor, input.tdee * (bmi >= 30 ? 0.70 : 0.75), macroFloor)
        if direction == .lose, calories < floor - 0.5 {
            calories = floor
            limit = .calorieFloor
        }
        if let override { calories = override }

        let factor = direction == .lose || input.highProtein ? 2.3 : (direction == .gain ? 2.2 : 2.0)
        let proteinCap = max(min(2.6 * fatFree, calories * 0.35 / 4), proteinFloor)
        let protein = (min(max(factor * fatFree, proteinFloor), proteinCap) / 5).rounded() * 5

        let fatFloor = max(calories * 0.20 / 9, 0.5 * reference)
        var fat = min(max(calories * 0.30 / 9, fatFloor), max(calories * 0.35 / 9, fatFloor))
        var carbs = (calories - protein * 4 - fat * 9) / 4
        if carbs < carbFloorG {
            fat = max(fatFloor, (calories - protein * 4 - carbFloorG * 4) / 9)
            carbs = max((calories - protein * 4 - fat * 9) / 4, carbFloorG)
        }

        let applied = input.weightKg > 0 ? abs(input.tdee - calories) * 7 / energyPerKg / input.weightKg * 100 : 0
        return PlannedTargets(calories: calories, proteinG: protein, fatG: fat, carbsG: carbs,
                              proteinFloorG: proteinFloor, proteinCapG: proteinCap, fatFloorG: fatFloor,
                              direction: direction, ratePercent: applied, limitedBy: limit)
    }

    static func carbMinimum(referenceWeightKg: Double, trainingMinutes: Double, hardEffort: Bool) -> Double {
        let gramsPerKg: Double
        switch trainingMinutes {
        case ..<30: gramsPerKg = 3
        case ..<90: gramsPerKg = hardEffort ? 5 : 4
        case ..<180: gramsPerKg = hardEffort ? 6 : 5
        case ..<240: gramsPerKg = 6
        default: gramsPerKg = hardEffort ? 8 : 6
        }
        return gramsPerKg * referenceWeightKg
    }

    static func dayMacros(_ targets: PlannedTargets, carbMinimumG: Double) -> (carbsG: Double, fatG: Double, isShort: Bool) {
        guard carbMinimumG > targets.carbsG else { return (targets.carbsG, targets.fatG, false) }
        let fat = max(targets.fatFloorG, targets.fatG - (carbMinimumG - targets.carbsG) * 4 / 9)
        let carbs = targets.carbsG + (targets.fatG - fat) * 9 / 4
        return (carbs, fat, carbs < carbMinimumG - 1)
    }

    static func limitWeeklyChange(_ calories: Double, previous: Double?) -> Double {
        guard let previous else { return calories }
        return min(max(calories, previous - maximumWeeklyChange), previous + maximumWeeklyChange)
    }

    static func safeguard(lossKgPerWeek: [Double], weightKg: Double) -> TargetSafeguard {
        if lossKgPerWeek.count >= 2, lossKgPerWeek.suffix(2).allSatisfy({ $0 > maximumWeeklyLossKg }) {
            return .maintenance
        }
        if weightKg > 0, lossKgPerWeek.count >= 3,
           lossKgPerWeek.suffix(3).allSatisfy({ $0 / weightKg * 100 > 1.0 }) {
            return .raise
        }
        return .none
    }
}
