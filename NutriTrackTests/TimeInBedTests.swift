import XCTest
@testable import NutriTrack

final class TimeInBedTests: XCTestCase {

    private let wokeAt = Date(timeIntervalSince1970: 1_790_000_000)

    private func hours(inBed minutes: Double) -> Double? {
        TimeInBed.hours(bedtime: wokeAt.addingTimeInterval(-minutes * 60), wakeTime: wokeAt)
    }

    func testWithoutABedtimeThereIsNothingToPrefill() {
        XCTAssertNil(TimeInBed.hours(bedtime: nil, wakeTime: wokeAt))
    }

    func testRoundsToTheNearestQuarterHour() {
        XCTAssertEqual(hours(inBed: 7 * 60 + 20), 7.25)
        XCTAssertEqual(hours(inBed: 7 * 60 + 23), 7.5)
        XCTAssertEqual(hours(inBed: 8 * 60), 8)
    }

    func testNightsShorterThanThreeOrLongerThanFourteenHoursAreIgnored() {
        XCTAssertNil(hours(inBed: 179))
        XCTAssertEqual(hours(inBed: 180), 3)
        XCTAssertEqual(hours(inBed: 14 * 60), 12)
        XCTAssertNil(hours(inBed: 14 * 60 + 1))
        XCTAssertNil(hours(inBed: -30))
    }

    func testLongNightsAreCappedAtTwelveHours() {
        XCTAssertEqual(hours(inBed: 13 * 60), 12)
    }

    func testBedtimeIsOnlyKeptWhenTheNightIsPlausible() {
        let good = wokeAt.addingTimeInterval(-8 * 3600)
        let stale = wokeAt.addingTimeInterval(-30 * 3600)
        XCTAssertEqual(TimeInBed.validBedtime(good, wakeTime: wokeAt), good)
        XCTAssertNil(TimeInBed.validBedtime(stale, wakeTime: wokeAt))
        XCTAssertNil(TimeInBed.validBedtime(nil, wakeTime: wokeAt))
    }

    func testLabelSaysHoursAndMinutes() {
        XCTAssertEqual(TimeInBed.label(8), "8 h")
        XCTAssertEqual(TimeInBed.label(7.25), "7 h 15 min")
        XCTAssertEqual(TimeInBed.label(5.5), "5 h 30 min")
    }

    func testSplitAndCombineStayInsideTheRange() {
        XCTAssertEqual(TimeInBed.split(7.75).hours, 7)
        XCTAssertEqual(TimeInBed.split(7.75).minutes, 45)
        XCTAssertEqual(TimeInBed.split(2).hours, 3)
        XCTAssertEqual(TimeInBed.split(2).minutes, 0)
        XCTAssertEqual(TimeInBed.combine(hours: 7, minutes: 15), 7.25)
        XCTAssertEqual(TimeInBed.combine(hours: 12, minutes: 45), 12)
        XCTAssertEqual(TimeInBed.combine(hours: 1, minutes: 0), 3)
    }

    func testPrefillFallsBackToTheDefaultWhenTheNightIsNotPlausible() {
        XCTAssertEqual(TimeInBed.prefill(bedtime: wokeAt.addingTimeInterval(-8 * 3600), wakeTime: wokeAt), 8)
        XCTAssertEqual(TimeInBed.prefill(bedtime: wokeAt.addingTimeInterval(-2 * 3600), wakeTime: wokeAt), 7.5)
        XCTAssertEqual(TimeInBed.prefill(bedtime: nil, wakeTime: wokeAt), 7.5)
    }
}
