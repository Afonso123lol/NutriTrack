import XCTest
@testable import NutriTrack

final class DayOverviewTests: XCTestCase {

    private func overview(color: DayColor = .green, hasCheckIn: Bool = true, sleep: Double? = 7.5,
                          kcal: Double = 1240, protein: Double = 82) -> DayOverview {
        DayOverview.make(color: color, hasCheckIn: hasCheckIn, sleepHours: sleep, sleepNeed: 8,
                         eatenKcal: kcal, targetKcal: 2894, proteinG: protein, targetProteinG: 180)
    }

    func testTheTodayCardSaysTheColourInWords() {
        XCTAssertEqual(overview().today.value, "Good to go")
        XCTAssertEqual(overview(color: .yellow).today.value, "Easy day")
        XCTAssertEqual(overview(color: .yellow).today.detail, "Lighter option")
        XCTAssertEqual(overview(color: .red).today.value, "Rest day")
        XCTAssertEqual(overview(color: .red).today.detail, "Training off")
    }

    func testBeforeTheCheckInTheCardsAskForIt() {
        let empty = overview(color: .unknown, hasCheckIn: false, sleep: nil)
        XCTAssertEqual(empty.today.value, "Check in")
        XCTAssertEqual(empty.sleep.value, "—")
        XCTAssertEqual(empty.sleep.detail, "need 8 h")
    }

    func testSleepIsHoursAgainstTheNeed() {
        XCTAssertEqual(overview(sleep: 7.5).sleep.value, "7.5 h")
        XCTAssertEqual(overview(sleep: 7.5).sleep.detail, "of 8 h need")
        XCTAssertEqual(overview(sleep: 0).sleep.value, "—")
    }

    func testFoodIsCaloriesAndProteinAgainstTheTargets() {
        let food = overview().food
        XCTAssertEqual(food.value, "1240")
        XCTAssertEqual(food.detail, "of 2894 kcal")
        XCTAssertEqual(food.extra, "82/180 g protein")
        XCTAssertEqual(food.accessibility, "Food, 1240, of 2894 kilocalories, 82 of 180 g protein")
    }
}
