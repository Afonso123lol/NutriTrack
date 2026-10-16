import XCTest
import CoreData
@testable import NutriTrack

@MainActor
final class CalibrationTests: XCTestCase {

    private let start = Date(timeIntervalSince1970: 1_790_000_000)

    private func weeks(_ count: Double) -> Date { start.addingTimeInterval(count * 7 * 86400) }

    func testCalibrationRunsUntilEightWeeksAndTenYellowDays() {
        XCTAssertTrue(Calibration.isRunning(startedAt: start, now: weeks(7), yellowDaysWithSession: 20))
        XCTAssertTrue(Calibration.isRunning(startedAt: start, now: weeks(9), yellowDaysWithSession: 9))
        XCTAssertFalse(Calibration.isRunning(startedAt: start, now: weeks(8), yellowDaysWithSession: 10))
    }

    func testTwelveWeeksEndItWhateverTheCount() {
        XCTAssertFalse(Calibration.isRunning(startedAt: start, now: weeks(12), yellowDaysWithSession: 0))
    }

    func testWithoutAStartTheCalibrationHasNotBegun() {
        XCTAssertFalse(Calibration.isRunning(startedAt: nil, now: weeks(20), yellowDaysWithSession: 50))
    }

    func testWhileCalibratingTheModeIsAlwaysSuggest() {
        XCTAssertEqual(Calibration.mode(stored: "auto", startedAt: start, now: weeks(1), yellowDaysWithSession: 0),
                       .suggest)
        XCTAssertEqual(Calibration.mode(stored: "off", startedAt: start, now: weeks(1), yellowDaysWithSession: 0),
                       .suggest)
    }

    func testAfterTheCalibrationTheStoredModeWins() {
        XCTAssertEqual(Calibration.mode(stored: "auto", startedAt: start, now: weeks(12), yellowDaysWithSession: 0),
                       .auto)
        XCTAssertEqual(Calibration.mode(stored: "off", startedAt: start, now: weeks(12), yellowDaysWithSession: 0),
                       .off)
        XCTAssertEqual(Calibration.mode(stored: "", startedAt: start, now: weeks(12), yellowDaysWithSession: 0),
                       .suggest)
        XCTAssertEqual(Calibration.mode(stored: "auto", startedAt: nil, now: weeks(12), yellowDaysWithSession: 0),
                       .auto)
    }

    func testWeeksDoneCountsFromTheStart() {
        XCTAssertEqual(Calibration.weeksDone(startedAt: start, now: weeks(3.5)), 3)
        XCTAssertEqual(Calibration.weeksDone(startedAt: nil, now: weeks(3.5)), 0)
    }

    func testTheFirstCheckInStartsTheCalibration() throws {
        let ctx = Persistence(inMemory: true).container.viewContext
        let profile = UserProfile(context: ctx)
        profile.id = UUID()
        let now = Date(timeIntervalSince1970: 1_790_000_000)
        var answers = CheckInAnswers(wakeTime: now)
        answers.energy = 4
        answers.quality = 4
        answers.soreness = 1
        answers.stress = 1

        DailyCheckIn.create(answers, bedtime: nil, now: now, in: ctx)
        XCTAssertEqual(profile.calibrationStartedAt, Calendar.current.startOfDay(for: now))

        DailyCheckIn.create(answers, bedtime: nil, now: now.addingTimeInterval(86400), in: ctx)
        XCTAssertEqual(profile.calibrationStartedAt, Calendar.current.startOfDay(for: now))
    }

    func testTheProfileReadsItsMode() {
        let ctx = Persistence(inMemory: true).container.viewContext
        let profile = UserProfile(context: ctx)
        XCTAssertEqual(profile.yellowModeValue, .suggest)
        profile.yellowMode = "off"
        XCTAssertEqual(profile.yellowModeValue, .off)
    }
}
