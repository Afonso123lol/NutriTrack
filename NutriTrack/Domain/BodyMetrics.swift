import Foundation

nonisolated enum GoalDirection: String, CaseIterable, Sendable {
    case lose
    case maintain
    case gain
}

nonisolated enum BodyMetrics {
    static func bmi(weightKg: Double, heightCm: Double) -> Double {
        let height = heightCm / 100
        guard height > 0 else { return 0 }
        return weightKg / (height * height)
    }

    static func referenceWeight(weightKg: Double, heightCm: Double) -> Double {
        let height = heightCm / 100
        return min(weightKg, 25 * height * height)
    }

    static func fatFreeMass(sex: Sex, weightKg: Double, heightCm: Double) -> Double {
        let index = bmi(weightKg: weightKg, heightCm: heightCm)
        let denominator = sex == .male ? 6680 + 216 * index : 8780 + 244 * index
        return 9270 * weightKg / denominator
    }

    static func restingRate(sex: Sex, age: Int, weightKg: Double, heightCm: Double) -> Double {
        let base = 10 * weightKg + 6.25 * heightCm - 5 * Double(age)
        return sex == .male ? base + 5 : base - 161
    }
}
