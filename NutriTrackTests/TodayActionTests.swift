import XCTest
@testable import NutriTrack

final class TodayActionTests: XCTestCase {

    private func pick(hasCheckIn: Bool = true, hasSessionToLog: Bool = false, mealsToday: Int = 0,
                      isDayClosed: Bool = false, hour: Int = 12) -> TodayAction? {
        TodayAction.pick(hasCheckIn: hasCheckIn, hasSessionToLog: hasSessionToLog, mealsToday: mealsToday,
                         isDayClosed: isDayClosed, hour: hour)
    }

    func testCheckInComesFirst() {
        XCTAssertEqual(pick(hasCheckIn: false, hasSessionToLog: true, mealsToday: 3, hour: 21), .checkIn)
    }

    func testThenTheSession() {
        XCTAssertEqual(pick(hasSessionToLog: true, mealsToday: 3, hour: 21), .session)
    }

    func testClosingTheDayIsOfferedInTheEveningWithAMeal() {
        XCTAssertEqual(pick(mealsToday: 2, hour: 19), .closeDay)
        XCTAssertNil(pick(mealsToday: 2, hour: 18))
        XCTAssertNil(pick(mealsToday: 0, hour: 22))
    }

    func testAClosedDayShowsItsResult() {
        XCTAssertEqual(pick(mealsToday: 3, isDayClosed: true, hour: 22), .dayClosed)
        XCTAssertEqual(pick(mealsToday: 3, isDayClosed: true, hour: 10), .dayClosed)
    }

    func testNothingToDo() {
        XCTAssertNil(pick())
    }
}
