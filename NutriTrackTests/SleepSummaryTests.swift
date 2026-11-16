import XCTest
@testable import NutriTrack

final class SleepSummaryTests: XCTestCase {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Lisbon")!
        return calendar
    }

    private func bedtime(day: Int, hour: Int, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }

    private func night(_ hours: Double, quality: Int = 3, bedtime: Date? = nil, energy: Int = 0) -> SleepSummary.Night {
        SleepSummary.Night(hours: hours, quality: quality, bedtime: bedtime, dayEnergy: energy)
    }

    private func summary(_ week: [SleepSummary.Night], recent: [SleepSummary.Night] = []) -> SleepSummary {
        SleepSummary.make(lastSeven: week, recent: recent, calendar: calendar)
    }

    func testTheWeekAverageAndTheNightsWithEnough() {
        let result = summary([night(6.5), night(7), night(7.5), night(8), night(6), night(7.25), night(7.5)])
        XCTAssertEqual(result.averageText, "7-night average 7.1 h")
        XCTAssertEqual(result.enoughNightsText, "5 of 7 nights with 7 h or more")
        XCTAssertEqual(result.averageQuality, 3)
    }

    func testNoNightsMeansNoSummary() {
        let result = summary([])
        XCTAssertNil(result.averageText)
        XCTAssertNil(result.enoughNightsText)
        XCTAssertNil(result.regularity)
    }

    func testRegularityNeedsFiveBedtimesAndCrossesMidnight() {
        let four = (10...13).map { night(7.5, bedtime: bedtime(day: $0, hour: 23, minute: 30)) }
        XCTAssertNil(summary(four).regularity)
        let mixed = [night(7.5, bedtime: bedtime(day: 10, hour: 23, minute: 30)),
                     night(7.5, bedtime: bedtime(day: 11, hour: 0, minute: 30)),
                     night(7.5, bedtime: bedtime(day: 12, hour: 23, minute: 30)),
                     night(7.5, bedtime: bedtime(day: 13, hour: 0, minute: 30)),
                     night(7.5, bedtime: bedtime(day: 14, hour: 0))]
        let regularity = summary(mixed).regularity
        XCTAssertEqual(regularity?.minutes ?? 0, 26.8, accuracy: 0.1)
        XCTAssertEqual(regularity?.band, .steady)
        XCTAssertEqual(regularity?.text, "Bedtime varies by 27 min")
    }

    func testTheHuangBands() {
        XCTAssertEqual(SleepSummary.RegularityBand(minutes: 30), .steady)
        XCTAssertEqual(SleepSummary.RegularityBand(minutes: 31), .fair)
        XCTAssertEqual(SleepSummary.RegularityBand(minutes: 61), .irregular)
        XCTAssertEqual(SleepSummary.RegularityBand(minutes: 91), .veryIrregular)
    }

    func testEnergyByHoursOnlyFromTwentyEightNights() {
        let few = Array(repeating: night(7.5, energy: 3), count: 27)
        XCTAssertNil(summary([], recent: few).energyByHours)
        let nights = Array(repeating: night(6, energy: 2), count: 10) + Array(repeating: night(7.5, energy: 3), count: 10)
            + Array(repeating: night(8.5, energy: 4), count: 8) + [night(8, energy: 0)]
        let bands = summary([], recent: nights).energyByHours
        XCTAssertEqual(bands?.map(\.label), ["Under 7 h", "7 to 8 h", "8 to 9 h", "9 h or more"])
        XCTAssertEqual(bands?.map(\.nights), [10, 10, 8, 0])
        XCTAssertEqual(bands?[0].averageEnergy, 2)
        XCTAssertNil(bands?[3].averageEnergy)
    }

    func testWithFewerThanSevenNightsTheAverageSaysHowMany() {
        XCTAssertEqual(summary([night(7.5), night(7.5)]).averageText, "Average 7.5 h over 2 nights")
        XCTAssertEqual(summary([night(6)]).averageText, "Average 6.0 h over 1 night")
    }

    func testRegularityTextAndBandUseTheSameRoundedMinutes() {
        let regularity = SleepSummary.Regularity(minutes: 30.5)
        XCTAssertEqual(regularity.text, "Bedtime varies by 31 min")
        XCTAssertEqual(regularity.band, .fair)
        XCTAssertEqual(SleepSummary.Regularity(minutes: 30.4).band, .steady)
    }
}
