import XCTest
@testable import NutriTrack

final class WeightTrendTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func weighIn(daysAgo: Double, _ weight: Double) -> WeighIn {
        WeighIn(date: now.addingTimeInterval(-daysAgo * 86400), weightKg: weight)
    }

    private func daily(slope: Double, days: [Int] = Array(0...27), noise: [Double] = []) -> [WeighIn] {
        days.enumerated().map { index, day in
            let jitter = noise.isEmpty ? 0 : noise[index % noise.count]
            return weighIn(daysAgo: Double(27 - day) + 0.5, 100 + slope * Double(day) + jitter)
        }
    }

    func testTrendStartsAtTheFirstWeighIn() {
        XCTAssertEqual(WeightTrend.ema([weighIn(daysAgo: 3, 80)]).map(\.weightKg), [80])
        XCTAssertTrue(WeightTrend.ema([]).isEmpty)
    }

    func testTrendMovesATenthOfTheDifferencePerDay() {
        let trend = WeightTrend.ema([weighIn(daysAgo: 2, 80), weighIn(daysAgo: 1, 81)])
        XCTAssertEqual(trend.last?.weightKg ?? 0, 80.1, accuracy: 0.0001)
    }

    func testTrendCatchesUpAfterAGap() {
        let trend = WeightTrend.ema([weighIn(daysAgo: 15, 80), weighIn(daysAgo: 1, 81)])
        XCTAssertEqual(trend.last?.weightKg ?? 0, 80 + (1 - pow(0.9, 14)), accuracy: 0.0001)
    }

    func testOnlyTheFirstWeighInOfADayCounts() {
        let calendar = Calendar.current
        let morning = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: now)!
        let evening = calendar.date(bySettingHour: 21, minute: 0, second: 0, of: now)!
        let kept = WeightTrend.firstOfEachDay([WeighIn(date: evening, weightKg: 82), WeighIn(date: morning, weightKg: 80)])
        XCTAssertEqual(kept, [WeighIn(date: morning, weightKg: 80)])
    }

    func testRateRecoversTheSlopeOfASteadyLoss() {
        let rate = WeightTrend.rate(daily(slope: -0.1), now: now)
        XCTAssertTrue(rate.isValid)
        XCTAssertEqual(rate.slopeKgPerDay, -0.1, accuracy: 0.0001)
        XCTAssertEqual(rate.kgPerWeek, -0.7, accuracy: 0.001)
        XCTAssertEqual(rate.standardError, 0, accuracy: 0.0001)
        XCTAssertEqual(rate.count, 28)
    }

    func testNoisyWeighInsGiveAStandardError() {
        let rate = WeightTrend.rate(daily(slope: -0.1, noise: [0.6, -0.6, 0.3, -0.3]), now: now)
        XCTAssertEqual(rate.slopeKgPerDay, -0.1, accuracy: 0.02)
        XCTAssertGreaterThan(rate.standardError, 0.005)
    }

    func testRateNeedsEightWeighIns() {
        XCTAssertFalse(WeightTrend.rate(daily(slope: -0.1, days: [0, 2, 4, 20, 22, 24, 26]), now: now).isValid)
        XCTAssertTrue(WeightTrend.rate(daily(slope: -0.1, days: [0, 2, 4, 13, 20, 22, 24, 26]), now: now).isValid)
    }

    func testRateNeedsWeighInsAtBothEnds() {
        XCTAssertFalse(WeightTrend.rate(daily(slope: -0.1, days: [0, 1, 2, 3, 4, 5, 6, 7, 26, 27]), now: now).isValid)
        XCTAssertFalse(WeightTrend.rate(daily(slope: -0.1, days: [0, 1, 20, 21, 22, 23, 24, 25, 26, 27]), now: now).isValid)
    }

    func testRateIgnoresWeighInsOlderThanTheWindow() {
        let old = (30...60).map { weighIn(daysAgo: Double($0), 120) }
        let rate = WeightTrend.rate(old + daily(slope: -0.1), now: now)
        XCTAssertEqual(rate.count, 28)
        XCTAssertEqual(rate.slopeKgPerDay, -0.1, accuracy: 0.0001)
    }

    private func point(day: Double, _ weight: Double, _ context: WeighInContext) -> WeighIn {
        WeighIn(date: now.addingTimeInterval((day - 28) * 86400), weightKg: weight, context: context)
    }

    private let fastedDays: [Double] = [0, 1, 7, 8, 14, 15, 21, 22]

    private var fastedLoss: [WeighIn] {
        fastedDays.map { point(day: $0, 100 - 0.1 * $0, .fasted) }
    }

    func testAFastedWeighInBeatsADaytimeOneOnTheSameDay() {
        let calendar = Calendar.current
        let early = calendar.date(bySettingHour: 6, minute: 0, second: 0, of: now)!
        let later = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: now)!
        let kept = WeightTrend.firstOfEachDay([WeighIn(date: early, weightKg: 82, context: .daytime),
                                               WeighIn(date: later, weightKg: 80, context: .fasted)])
        XCTAssertEqual(kept, [WeighIn(date: later, weightKg: 80, context: .fasted)])
    }

    func testWeighInsAfterTrainingAreLeftOut() {
        XCTAssertTrue(WeightTrend.firstOfEachDay([WeighIn(date: now, weightKg: 79, context: .afterTraining)]).isEmpty)
        let withSweat = fastedLoss + [5, 12, 19].map { point(day: $0, 90, .afterTraining) }
        let rate = WeightTrend.rate(withSweat, now: now)
        XCTAssertEqual(rate.slopeKgPerDay, -0.1, accuracy: 0.0001)
        XCTAssertEqual(rate.count, 8)
    }

    func testDaytimeWeighInsShareTheSlopeWithTheirOwnOffset() {
        let daytime = [2, 4, 9, 11, 16, 18, 23, 25].map { point(day: $0, 101 - 0.1 * $0, .daytime) }
        let rate = WeightTrend.rate(fastedLoss + daytime, now: now)
        XCTAssertTrue(rate.isValid)
        XCTAssertEqual(rate.count, 16)
        XCTAssertEqual(rate.slopeKgPerDay, -0.1, accuracy: 0.0001)
        XCTAssertEqual(rate.daytimeOffsetKg ?? 0, 1.0, accuracy: 0.0001)
        XCTAssertEqual(rate.standardError, 0, accuracy: 0.0001)
    }

    func testFewerThanThreeDaytimeWeighInsAreIgnored() {
        let rate = WeightTrend.rate(fastedLoss + [point(day: 3, 105, .daytime), point(day: 10, 105, .daytime)], now: now)
        XCTAssertEqual(rate.slopeKgPerDay, -0.1, accuracy: 0.0001)
        XCTAssertNil(rate.daytimeOffsetKg)
        XCTAssertEqual(rate.count, 8)
    }

    func testStandardErrorWithTwoKindsOfWeighIn() {
        let fasted = [0, 10, 20].map { point(day: $0, 10, .fasted) }
        let daytime = [point(day: 5, 11.3, .daytime), point(day: 15, 11.0, .daytime), point(day: 25, 11.3, .daytime)]
        let rate = WeightTrend.rate(fasted + daytime, now: now)
        XCTAssertEqual(rate.slopeKgPerDay, 0, accuracy: 0.0001)
        XCTAssertEqual(rate.daytimeOffsetKg ?? 0, 1.2, accuracy: 0.0001)
        XCTAssertEqual(rate.standardError, 0.0070711, accuracy: 0.000001)
        XCTAssertFalse(rate.isValid)
    }

    func testTrendRemovesTheDaytimeOffset() {
        let mixed = [weighIn(daysAgo: 2, 80),
                     WeighIn(date: now.addingTimeInterval(-86400), weightKg: 82, context: .daytime)]
        XCTAssertEqual(WeightTrend.ema(mixed, daytimeOffsetKg: 1).last?.weightKg ?? 0, 80.1, accuracy: 0.0001)
    }

    func testTrendSkipsDaytimeWeighInsUntilTheOffsetIsKnown() {
        let mixed = [weighIn(daysAgo: 2, 80),
                     WeighIn(date: now.addingTimeInterval(-86400), weightKg: 82, context: .daytime)]
        XCTAssertEqual(WeightTrend.ema(mixed).map(\.weightKg), [80])
    }

    func testTrendUsesDaytimeWeighInsWhenThereAreNoFastedOnes() {
        let daytimeOnly = [WeighIn(date: now.addingTimeInterval(-2 * 86400), weightKg: 80, context: .daytime),
                           WeighIn(date: now.addingTimeInterval(-86400), weightKg: 81, context: .daytime)]
        XCTAssertEqual(WeightTrend.ema(daytimeOnly).last?.weightKg ?? 0, 80.1, accuracy: 0.0001)
    }
}
