import Foundation

nonisolated struct DayNutrients: Equatable, Sendable {
    let food: NutritionAnalysis
    let supplements: NutritionAnalysis
}

nonisolated enum WeekIntake {
    static func average(_ days: [DayNutrients]) -> (total: NutritionAnalysis, supplements: NutritionAnalysis) {
        guard !days.isEmpty else { return (.empty, .empty) }
        let share = 1 / Double(days.count)
        let food = NutritionAnalysis.sum(days.map(\.food)).scaled(by: share)
        let supplements = NutritionAnalysis.sum(days.map(\.supplements)).scaled(by: share)
        return (NutritionAnalysis.sum([food, supplements]), supplements)
    }
}
