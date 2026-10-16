struct MacroTargets {
    let calories: Double
    let proteinG: Double
    let carbsG: Double
    let fatG: Double
    let limits: NutrientLimits
}

struct NutritionCalculator {
    static func calculate(sex: Sex, age: Int, weightKg: Double, heightCm: Double, goal: Goal,
                          activityFactor: Double = 0, ratePercent: Double = 0) -> MacroTargets {
        let resting = mifflinStJeor(sex: sex, weightKg: weightKg, heightCm: heightCm, age: age)
        let tdee = ExpenditureEstimator.formula(restingRate: resting, activityFactor: activityFactor)
        let input = TargetInput(sex: sex, age: age, weightKg: weightKg, heightCm: heightCm,
                                direction: goal.direction, ratePercent: ratePercent, tdee: tdee)
        return targets(from: TargetPlanner.plan(input), sex: sex, age: age, weightKg: weightKg, goal: goal)
    }

    static func targets(from planned: PlannedTargets, sex: Sex, age: Int, weightKg: Double, goal: Goal) -> MacroTargets {
        let limits = NutrientLimits.calculate(sex: sex, age: age, weightKg: weightKg, goal: goal,
                                              targetCalories: planned.calories,
                                              proteinRange: planned.proteinFloorG...planned.proteinCapG)
        return MacroTargets(calories: planned.calories, proteinG: planned.proteinG, carbsG: planned.carbsG,
                            fatG: planned.fatG, limits: limits)
    }

    static func mifflinStJeor(sex: Sex, weightKg: Double, heightCm: Double, age: Int) -> Double {
        BodyMetrics.restingRate(sex: sex, age: age, weightKg: weightKg, heightCm: heightCm)
    }
}
