import XCTest
@testable import NutriTrack

final class EveningQuestionTests: XCTestCase {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Lisbon")!
        return calendar
    }

    private func date(day: Int, hour: Int, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }

    func testBeforeMidnightTheQuestionIsAboutToday() {
        XCTAssertEqual(EveningQuestion.day(for: date(day: 13, hour: 23, minute: 30), calendar: calendar),
                       date(day: 13, hour: 0))
    }

    func testAfterMidnightTheQuestionIsStillAboutTheDayBefore() {
        XCTAssertEqual(EveningQuestion.day(for: date(day: 14, hour: 1, minute: 30), calendar: calendar),
                       date(day: 13, hour: 0))
        XCTAssertEqual(EveningQuestion.day(for: date(day: 14, hour: 4, minute: 59), calendar: calendar),
                       date(day: 13, hour: 0))
    }

    func testFromFiveInTheMorningItIsANewDay() {
        XCTAssertEqual(EveningQuestion.day(for: date(day: 14, hour: 5), calendar: calendar),
                       date(day: 14, hour: 0))
    }

    func testAsksOnlyWithACheckInAndNoAnswerYet() {
        XCTAssertTrue(EveningQuestion.shouldAsk(hasCheckIn: true, dayEnergy: 0))
        XCTAssertFalse(EveningQuestion.shouldAsk(hasCheckIn: false, dayEnergy: 0))
        XCTAssertFalse(EveningQuestion.shouldAsk(hasCheckIn: true, dayEnergy: 3))
    }
}
