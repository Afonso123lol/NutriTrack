import XCTest
@testable import NutriTrack

final class BirthDateTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    func testAgeChangesOnTheBirthday() {
        let born = date(2004, 3, 12)
        XCTAssertEqual(BirthDate.age(bornOn: born, now: date(2026, 3, 11), calendar: calendar), 21)
        XCTAssertEqual(BirthDate.age(bornOn: born, now: date(2026, 3, 12), calendar: calendar), 22)
        XCTAssertEqual(BirthDate.age(bornOn: born, now: date(2026, 10, 8), calendar: calendar), 22)
    }

    func testAgeIsNeverNegative() {
        XCTAssertEqual(BirthDate.age(bornOn: date(2030, 1, 1), now: date(2026, 1, 1), calendar: calendar), 0)
    }

    func testBirthdayIsTheSameDayAndMonth() {
        let born = date(2004, 3, 12)
        XCTAssertTrue(BirthDate.isBirthday(bornOn: born, now: date(2027, 3, 12), calendar: calendar))
        XCTAssertFalse(BirthDate.isBirthday(bornOn: born, now: date(2027, 3, 13), calendar: calendar))
        XCTAssertFalse(BirthDate.isBirthday(bornOn: born, now: date(2027, 4, 12), calendar: calendar))
    }

    func testLeapDayBirthdayFallsOnTheTwentyEighthInOtherYears() {
        let born = date(2004, 2, 29)
        XCTAssertTrue(BirthDate.isBirthday(bornOn: born, now: date(2028, 2, 29), calendar: calendar))
        XCTAssertFalse(BirthDate.isBirthday(bornOn: born, now: date(2028, 2, 28), calendar: calendar))
        XCTAssertTrue(BirthDate.isBirthday(bornOn: born, now: date(2027, 2, 28), calendar: calendar))
        XCTAssertFalse(BirthDate.isBirthday(bornOn: born, now: date(2027, 3, 1), calendar: calendar))
    }

    func testAllowedRangeGoesFromOneHundredToFourteenYearsAgo() {
        let range = BirthDate.allowedRange(now: date(2026, 10, 8), calendar: calendar)
        XCTAssertEqual(range.lowerBound, date(1926, 10, 8))
        XCTAssertEqual(range.upperBound, date(2012, 10, 8))
    }

    func testSuggestedDateIsTheFirstOfJanuaryTwentyFiveYearsBack() {
        XCTAssertEqual(BirthDate.suggested(now: date(2026, 10, 8), calendar: calendar),
                       calendar.date(from: DateComponents(year: 2001, month: 1, day: 1)))
    }
}
