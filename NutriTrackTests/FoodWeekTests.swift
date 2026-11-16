import XCTest
@testable import NutriTrack

final class FoodWeekTests: XCTestCase {

    private func day(_ calories: Double, protein: Double = 150, fiber: Double = 30, saturated: Double = 20,
                     sodium: Double = 2000, long: Bool = false) -> FoodWeek.Day {
        FoodWeek.Day(calories: calories, proteinG: protein, fiberG: fiber, saturatedFatG: saturated,
                     sodiumMg: sodium, hasLongSession: long)
    }

    private func week(_ days: [FoodWeek.Day]) -> FoodWeek {
        FoodWeek.make(days: days, targetCalories: 2500, targetProteinG: 150, windowDays: 7)
    }

    func testWithoutCompleteDaysOnlyTheCountShows() {
        let result = week([])
        XCTAssertEqual(result.completeText, "0 of 7 complete days")
        XCTAssertNil(result.caloriesText)
        XCTAssertNil(result.proteinText)
        XCTAssertNil(result.sodiumText)
    }

    func testCaloriesAverageAndRange() {
        let result = week([day(2200), day(2600), day(2400)])
        XCTAssertEqual(result.completeText, "3 of 7 complete days")
        XCTAssertEqual(result.caloriesText, "2400 kcal a day, target 2500")
        XCTAssertEqual(result.caloriesRangeText, "2200 to 2600 kcal")
    }

    func testProteinCountsTheDaysThatReachedTheTarget() {
        let result = week([day(2500, protein: 160), day(2500, protein: 150), day(2500, protein: 120)])
        XCTAssertEqual(result.proteinText, "Target reached on 2 of 3 days")
    }

    func testFibrePerThousandKilocaloriesEaten() {
        let result = week([day(2000, fiber: 24), day(3000, fiber: 36)])
        XCTAssertEqual(result.fiberText, "12 g per 1000 kcal, aim 14")
    }

    func testSaturatedFatAsShareOfEnergyEaten() {
        let result = week([day(2000, saturated: 20), day(2000, saturated: 24)])
        XCTAssertEqual(result.saturatedText, "10% of energy, keep under 10%")
    }

    func testSodiumLeavesOutLongSessionDaysAndCarriesTheNote() {
        let result = week([day(2500, sodium: 1800), day(2500, sodium: 2200), day(2500, sodium: 5000, long: true)])
        XCTAssertEqual(result.sodiumText, "2000 mg a day, keep under 2000")
        XCTAssertEqual(result.sodiumNote, "Leaves out 1 day with a session over 2 h. Less reliable for meals described by text.")
    }

    func testSodiumWithOnlyLongDaysIsNotShown() {
        XCTAssertNil(week([day(2500, sodium: 5000, long: true)]).sodiumText)
    }
}
