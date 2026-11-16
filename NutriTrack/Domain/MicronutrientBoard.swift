import Foundation

nonisolated enum BoardPeriod: Equatable, Sendable {
    case today
    case week(completeDays: Int)
}

struct MicronutrientBoard {
    struct Group: Identifiable {
        let title: String
        let readings: [NutrientReading]

        var id: String { title }
        var summary: String {
            readings.contains { $0.showsStatus } ? MicronutrientBoard.summary(of: readings) : ""
        }
    }

    static let keyNames = ["Iron", "Vitamin D", "B12", "Magnesium", "Zinc", "Calcium", "Potassium"]
    static let weekDays = 7
    static let minimumCompleteDays = 4

    let key: [NutrientReading]
    let groups: [Group]
    let hasIntake: Bool
    let period: BoardPeriod

    var headline: String {
        switch period {
        case .today:
            return hasIntake ? "Today so far, against the daily reference." : "Nothing logged yet today."
        case .week(let completeDays):
            if completeDays == 0 { return "No complete days in the last \(Self.weekDays)." }
            let days = "\(completeDays) of \(Self.weekDays) complete days."
            guard completeDays >= Self.minimumCompleteDays else { return "\(days) Too few to judge the week." }
            let onTarget = key.filter { $0.status == .good }.count
            return "\(days) \(onTarget) of \(key.count) key nutrients on target."
        }
    }

    static func summary(of readings: [NutrientReading]) -> String {
        let low = readings.filter { $0.rule != .limit && $0.status == .low }.count
        let over = readings.filter { $0.status == .over }.count
        var parts: [String] = []
        if low > 0 { parts.append("\(low) low") }
        if over > 0 { parts.append("\(over) over limit") }
        return parts.isEmpty ? "On target" : parts.joined(separator: " · ")
    }

    static func make(total: NutritionAnalysis, supplements: NutritionAnalysis, targets: MacroTargets,
                     period: BoardPeriod, hasLongSession: Bool,
                     weekSodiumWithoutLongDays: (mg: Double, leftOut: Int)? = nil) -> MicronutrientBoard {
        let limits = targets.limits
        let showsStatus: Bool
        switch period {
        case .today: showsStatus = false
        case .week(let completeDays): showsStatus = completeDays >= minimumCompleteDays
        }

        func referenced(_ name: String, _ value: Double, _ taken: Double, _ source: NutrientReference,
                        _ unit: String) -> NutrientReading {
            let rule: NutrientReading.Rule
            if source.upper == nil {
                rule = .floor
            } else if source.upperScope == .supplementsOnly {
                rule = .supplementLimit(taken: taken)
            } else {
                rule = .range
            }
            return NutrientReading(name: name, value: value, unit: unit, floor: source.reference,
                                   ceiling: source.upper ?? 0, rule: rule, showsStatus: showsStatus,
                                   overWord: source.isUpperSafeLevel ? "Above safe level" : "Over limit",
                                   basis: source.basis, fromSupplements: taken)
        }
        func limit(_ name: String, _ value: Double, _ ceiling: Double, _ unit: String, _ basis: String) -> NutrientReading {
            NutrientReading(name: name, value: value, unit: unit, floor: 0, ceiling: ceiling, rule: .limit,
                            showsStatus: showsStatus, basis: basis)
        }
        func plain(_ name: String, _ value: Double, _ unit: String, basis: String? = nil,
                   note: String? = nil) -> NutrientReading {
            NutrientReading(name: name, value: value, unit: unit, floor: 0, ceiling: 0, rule: .plain,
                            showsStatus: showsStatus, basis: basis, note: note)
        }

        let fats = [
            NutrientReading(name: "Fiber", value: total.fiberG, unit: "g", floor: limits.fiberMinG, ceiling: 0,
                            rule: .floor, showsStatus: showsStatus,
                            basis: "Target: 14 g per 1000 kcal (DRI). EFSA sets 25 g a day for adults."),
            plain("Omega-3", total.omega3G, "g",
                  basis: "No reference shown: the European reference is for EPA and DHA, which the app cannot separate yet."),
            plain("Sugar", total.sugarG, "g",
                  basis: "No limit shown: the WHO limit is for free sugars and the app measures total sugar."),
            limit("Saturated fat", total.saturatedFatG, targets.calories * 0.10 / 9, "g", "Limit: WHO, 10 % of energy."),
            limit("Trans fat", total.transFatG ?? 0, targets.calories * 0.01 / 9, "g", "Limit: WHO, 1 % of energy."),
        ]
        let sodium: NutrientReading
        if hasLongSession && period == .today {
            sodium = plain("Sodium", total.sodiumMg, "mg", note: "Long session today: sodium needs are higher.")
        } else if period != .today, let week = weekSodiumWithoutLongDays, week.leftOut > 0 {
            sodium = NutrientReading(name: "Sodium", value: week.mg, unit: "mg", floor: 0, ceiling: limits.sodiumMaxMg,
                                     rule: .limit, showsStatus: showsStatus, basis: "Limit: EFSA and WHO, 2 g a day.",
                                     note: "Leaves out \(week.leftOut) \(week.leftOut == 1 ? "day" : "days") with a session over 2 h.")
        } else {
            sodium = limit("Sodium", total.sodiumMg, limits.sodiumMaxMg, "mg", "Limit: EFSA and WHO, 2 g a day.")
        }
        let minerals = [
            sodium,
            referenced("Potassium", total.potassiumMg, supplements.potassiumMg, limits.potassium, "mg"),
            referenced("Calcium", total.calciumMg, supplements.calciumMg, limits.calcium, "mg"),
            referenced("Iron", total.ironMg, supplements.ironMg, limits.iron, "mg"),
            referenced("Zinc", total.zincMg, supplements.zincMg, limits.zinc, "mg"),
            referenced("Magnesium", total.magnesiumMg, supplements.magnesiumMg, limits.magnesium, "mg"),
            referenced("Phosphorus", total.phosphorusMg, supplements.phosphorusMg, limits.phosphorus, "mg"),
            referenced("Selenium", total.seleniumUg, supplements.seleniumUg, limits.selenium, "µg"),
            referenced("Copper", total.copperUg, supplements.copperUg, limits.copper, "µg"),
        ]
        let vitamins = [
            referenced("Vitamin A", total.vitaminAUg ?? 0, supplements.vitaminAUg ?? 0, limits.vitaminA, "µg"),
            referenced("Vitamin C", total.vitaminCMg, supplements.vitaminCMg, limits.vitaminC, "mg"),
            referenced("Vitamin D", total.vitaminDUg, supplements.vitaminDUg, limits.vitaminD, "µg"),
            referenced("Vitamin E", total.vitaminEMg, supplements.vitaminEMg, limits.vitaminE, "mg"),
            referenced("Vitamin K", total.vitaminKUg, supplements.vitaminKUg, limits.vitaminK, "µg"),
            referenced("B1 Thiamine", total.vitaminB1Mg, supplements.vitaminB1Mg, limits.vitaminB1, "mg"),
            referenced("B2 Riboflavin", total.vitaminB2Mg, supplements.vitaminB2Mg, limits.vitaminB2, "mg"),
            referenced("B3 Niacin", total.vitaminB3Mg, supplements.vitaminB3Mg, limits.vitaminB3, "mg"),
            referenced("B5 Pantothenic", total.vitaminB5Mg, supplements.vitaminB5Mg, limits.vitaminB5, "mg"),
            referenced("B6", total.vitaminB6Mg, supplements.vitaminB6Mg, limits.vitaminB6, "mg"),
            referenced("B12", total.vitaminB12Ug, supplements.vitaminB12Ug, limits.vitaminB12, "µg"),
            referenced("Folate (B9)", total.folateUg, supplements.folateUg, limits.folate, "µg"),
        ]

        let all = fats + minerals + vitamins
        let key = keyNames.compactMap { name in all.first { $0.name == name } }
        func rest(_ readings: [NutrientReading]) -> [NutrientReading] {
            readings.filter { !keyNames.contains($0.name) }
        }
        return MicronutrientBoard(
            key: key,
            groups: [
                Group(title: "Vitamins", readings: rest(vitamins)),
                Group(title: "Minerals", readings: rest(minerals)),
                Group(title: "Fats, fibre and sugar", readings: rest(fats)),
            ],
            hasIntake: total.calories > 0 || all.contains { $0.value > 0 },
            period: period)
    }
}
