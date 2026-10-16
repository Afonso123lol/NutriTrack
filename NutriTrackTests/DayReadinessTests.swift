import XCTest
@testable import NutriTrack

final class DayReadinessTests: XCTestCase {

    private func state(energy: Int? = 4, sleep: Double? = 8, sick: Bool = false, pain: Bool = false,
                       baseline: [Int] = []) -> DayState {
        DayState(energy: energy, sleepHours: sleep, isSick: sick, hasPain: pain, energyBaseline: baseline)
    }

    func testIllnessAndPainAreTheOnlyRedDays() {
        XCTAssertEqual(DayReadiness.color(state(sick: true)), .red)
        XCTAssertEqual(DayReadiness.color(state(pain: true)), .red)
        XCTAssertEqual(DayReadiness.color(state(energy: 1, sleep: 3)), .yellow)
    }

    func testSixHoursOrLessIsYellowAndFourAndAHalfTooMuchTheSame() {
        XCTAssertEqual(DayReadiness.color(state(sleep: 6)), .yellow)
        XCTAssertEqual(DayReadiness.color(state(sleep: 4.5)), .yellow)
        XCTAssertEqual(DayReadiness.color(state(sleep: 6.25)), .green)
    }

    func testEnergyOfTwoOrLessIsYellow() {
        XCTAssertEqual(DayReadiness.color(state(energy: 2)), .yellow)
        XCTAssertEqual(DayReadiness.color(state(energy: 3)), .green)
    }

    func testWithABaselineEnergyOneSpreadBelowTheMeanIsYellow() {
        let steady = Array(repeating: 4, count: 14)
        XCTAssertEqual(DayReadiness.color(state(energy: 3, baseline: steady)), .yellow)
        let mixed = [4, 4, 4, 3, 4, 3, 4, 4, 3, 4, 4, 3, 4, 4]
        XCTAssertEqual(DayReadiness.color(state(energy: 3, baseline: mixed)), .green)
    }

    func testABaselineShorterThanFourteenDaysIsIgnored() {
        XCTAssertEqual(DayReadiness.color(state(energy: 3, baseline: Array(repeating: 5, count: 13))), .green)
    }

    func testMissingSleepHoursDoNotMakeTheDayYellow() {
        XCTAssertEqual(DayReadiness.color(state(sleep: nil)), .green)
        XCTAssertEqual(DayReadiness.color(state(sleep: 0)), .green)
    }

    func testReasonsSayWhy() {
        XCTAssertEqual(DayReadiness.reasons(state(sick: true)).map(\.text), ["You marked yourself ill."])
        XCTAssertEqual(DayReadiness.reasons(state(pain: true)).map(\.text),
                       ["You marked pain that changes how you walk."])
        XCTAssertEqual(DayReadiness.reasons(state(sleep: 5.5)).map(\.text),
                       ["Short night: the session may feel harder, mostly later in the day."])
        XCTAssertEqual(DayReadiness.reasons(state(energy: 2)).map(\.text), ["Energy is 2 of 5."])
        XCTAssertEqual(DayReadiness.reasons(state(energy: 3, baseline: Array(repeating: 4, count: 14))).map(\.text),
                       ["Energy is below your usual."])
        XCTAssertTrue(DayReadiness.reasons(state()).isEmpty)
    }

    func testAShortNightAndLowEnergyGiveBothReasons() {
        let reasons = DayReadiness.reasons(state(energy: 2, sleep: 5))
        XCTAssertEqual(reasons.count, 2)
        XCTAssertEqual(DayReadiness.color(state(energy: 2, sleep: 5)), .yellow)
    }
}
