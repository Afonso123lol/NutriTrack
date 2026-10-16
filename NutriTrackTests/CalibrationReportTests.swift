import XCTest
@testable import NutriTrack

final class CalibrationReportTests: XCTestCase {

    private func day(_ color: DayColor, rpe: Int? = 5, done: Double? = 60, planned: Double? = 60,
                     dayEnergy: Int? = 3, choice: SuggestionChoice? = nil) -> CalibrationReport.Day {
        CalibrationReport.Day(color: color, rpe: rpe, doneMinutes: done, plannedMinutes: planned,
                              dayEnergy: dayEnergy, choice: choice)
    }

    func testItSeparatesTheAcceptedDaysFromTheInformativeOnes() {
        let report = CalibrationReport.make([
            day(.yellow, choice: .applied), day(.yellow, choice: .applied),
            day(.yellow, choice: .kept), day(.green)
        ])
        XCTAssertEqual(report.acceptedSide.sessions, 2)
        XCTAssertEqual(report.yellowSide.sessions, 1)
        XCTAssertEqual(report.greenSide.sessions, 1)
    }

    func testItTakesTheMedianOfEachSide() {
        let report = CalibrationReport.make([
            day(.yellow, rpe: 7, done: 40, dayEnergy: 2, choice: .kept),
            day(.yellow, rpe: 6, done: 50, dayEnergy: 3, choice: .kept),
            day(.yellow, rpe: 8, done: 30, dayEnergy: 2, choice: .kept),
            day(.green, rpe: 5, done: 60, dayEnergy: 4),
            day(.green, rpe: 4, done: 60, dayEnergy: 4)
        ])
        XCTAssertEqual(report.yellowSide.medianRPE, 7)
        XCTAssertEqual(report.yellowSide.medianDoneShare, 40.0 / 60)
        XCTAssertEqual(report.yellowSide.medianDayEnergy, 2)
        XCTAssertEqual(report.greenSide.medianRPE, 4.5)
        XCTAssertEqual(report.greenSide.medianDayEnergy, 4)
    }

    func testNoVerdictWithFewerThanTenInformativeYellowDays() {
        let few = CalibrationReport.make(Array(repeating: day(.yellow, choice: .kept), count: 9)
                                         + Array(repeating: day(.green), count: 20))
        XCTAssertNil(few.verdict)
        XCTAssertFalse(few.hasEnough)
    }

    func testItSaysWhenTheYellowDaysLookDifferent() {
        let yellow = Array(repeating: day(.yellow, rpe: 8, done: 40, dayEnergy: 2, choice: .kept), count: 10)
        let green = Array(repeating: day(.green, rpe: 4, done: 60, dayEnergy: 4), count: 10)
        let report = CalibrationReport.make(yellow + green)
        XCTAssertTrue(report.hasEnough)
        XCTAssertEqual(report.verdict, "Your yellow days do look harder than your green ones.")
    }

    func testItSaysWhenTheyLookTheSame() {
        let yellow = Array(repeating: day(.yellow, rpe: 5, done: 60, dayEnergy: 4, choice: .kept), count: 10)
        let green = Array(repeating: day(.green, rpe: 5, done: 60, dayEnergy: 4), count: 10)
        let report = CalibrationReport.make(yellow + green)
        XCTAssertEqual(report.verdict, "Your yellow days look like your green ones. The rule may not be for you.")
    }

    func testDaysWithoutASessionStillCountForTheDayEnergy() {
        let report = CalibrationReport.make([
            day(.yellow, rpe: nil, done: nil, planned: nil, dayEnergy: 2, choice: .kept),
            day(.green, rpe: nil, done: nil, planned: nil, dayEnergy: 4)
        ])
        XCTAssertEqual(report.yellowSide.sessions, 0)
        XCTAssertEqual(report.yellowSide.medianDayEnergy, 2)
        XCTAssertNil(report.yellowSide.medianRPE)
        XCTAssertNil(report.yellowSide.medianDoneShare)
    }

    func testNoVerdictWhenNothingWasMeasuredOnBothSides() {
        let empty = Array(repeating: day(.yellow, rpe: nil, done: nil, planned: nil, dayEnergy: nil, choice: .kept), count: 10)
            + Array(repeating: day(.green, rpe: nil, done: nil, planned: nil, dayEnergy: nil), count: 10)
        XCTAssertNil(CalibrationReport.make(empty).verdict)
    }
}
