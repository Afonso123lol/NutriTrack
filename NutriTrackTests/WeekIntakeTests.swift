import XCTest
@testable import NutriTrack

final class WeekIntakeTests: XCTestCase {

    private func analysis(iron: Double, transFat: Double? = nil) -> NutritionAnalysis {
        var result = NutritionAnalysis.empty
        result.ironMg = iron
        result.transFatG = transFat
        return result
    }

    func testNoDaysGiveAnEmptyAverage() {
        let average = WeekIntake.average([])
        XCTAssertEqual(average.total.ironMg, 0)
        XCTAssertEqual(average.supplements.ironMg, 0)
    }

    func testAverageAddsFoodAndSupplementsAndKeepsSupplementsApart() {
        let days = [
            DayNutrients(food: analysis(iron: 10), supplements: analysis(iron: 14)),
            DayNutrients(food: analysis(iron: 6), supplements: analysis(iron: 0)),
        ]
        let average = WeekIntake.average(days)
        XCTAssertEqual(average.total.ironMg, 15, accuracy: 0.0001)
        XCTAssertEqual(average.supplements.ironMg, 7, accuracy: 0.0001)
    }

    func testOptionalNutrientsAreAveragedOverAllDays() {
        let days = [
            DayNutrients(food: analysis(iron: 0, transFat: 3), supplements: .empty),
            DayNutrients(food: analysis(iron: 0), supplements: .empty),
        ]
        XCTAssertEqual(WeekIntake.average(days).total.transFatG ?? -1, 1.5, accuracy: 0.0001)
    }
}
