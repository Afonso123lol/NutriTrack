import XCTest
@testable import NutriTrack

final class ExpenditureEstimatorTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func rate(slope: Double = -0.1, error: Double = 0.01, valid: Bool = true) -> WeightRate {
        WeightRate(slopeKgPerDay: slope, standardError: error, count: 12, isValid: valid)
    }

    private func days(_ daysAgo: [Int], calories: Double = 2500) -> [DayIntake] {
        daysAgo.map { DayIntake(date: now.addingTimeInterval(-Double($0) * 86400 - 3600), calories: calories) }
    }

    private let fullLog = Array(0..<28).filter { $0 % 7 < 5 }

    private func update(previous: Double = 3000, resting: Double = 2000, rate: WeightRate? = nil,
                        intake: [DayIntake]? = nil) -> ExpenditureResult {
        ExpenditureEstimator.update(previousTDEE: previous, restingRate: resting, rate: rate ?? self.rate(),
                                    completeDays: intake ?? days(fullLog), now: now)
    }

    func testFormulaUsesTheActivityFactor() {
        XCTAssertEqual(ExpenditureEstimator.formula(restingRate: 2000, activityFactor: 1.4), 2800)
        XCTAssertEqual(ExpenditureEstimator.formula(restingRate: 2000, activityFactor: 0), 3100)
    }

    func testUpdateMovesHalfWayToTheObservedExpenditure() {
        let result = update()
        XCTAssertEqual(result.status, .updated)
        XCTAssertEqual(result.completeDays, 20)
        XCTAssertEqual(result.tdee, 3135, accuracy: 0.001)
    }

    func testUpdateIsLimitedToOneHundredAndFiftyPerWeek() {
        XCTAssertEqual(update(intake: days(fullLog, calories: 3200)).tdee, 3150, accuracy: 0.001)
        XCTAssertEqual(update(intake: days(fullLog, calories: 1500)).tdee, 2850, accuracy: 0.001)
    }

    func testEstimateStaysWithinMultiplesOfTheRestingRate() {
        XCTAssertEqual(update(previous: 2450, intake: days(fullLog, calories: 1000)).tdee, 2400, accuracy: 0.001)
        XCTAssertEqual(update(previous: 4750, intake: days(fullLog, calories: 6000)).tdee, 4800, accuracy: 0.001)
    }

    func testInvalidRateKeepsThePreviousValue() {
        let result = update(rate: rate(valid: false))
        XCTAssertEqual(result.status, .needsWeighIns)
        XCTAssertEqual(result.tdee, 3000)
    }

    func testTooFewCompleteDaysKeepsThePreviousValue() {
        let result = update(intake: days(Array(0..<19)))
        XCTAssertEqual(result.status, .needsCompleteDays)
        XCTAssertEqual(result.completeDays, 19)
        XCTAssertEqual(result.tdee, 3000)
    }

    func testEveryWeekNeedsFourCompleteDays() {
        let lopsided = Array(0..<21) + [21, 22, 23]
        let result = update(intake: days(lopsided))
        XCTAssertEqual(result.status, .needsCompleteDays)
        XCTAssertEqual(result.completeDays, 24)
    }

    func testNoisySlopeKeepsThePreviousValue() {
        XCTAssertEqual(update(rate: rate(error: 0.04)).status, .tooNoisy)
        XCTAssertEqual(update(rate: rate(error: 0.032)).status, .updated)
    }

    func testDaysOutsideTheWindowAreIgnored() {
        let result = update(intake: days(fullLog) + days([30, 31, 40], calories: 9000))
        XCTAssertEqual(result.completeDays, 20)
        XCTAssertEqual(result.tdee, 3135, accuracy: 0.001)
    }
}
