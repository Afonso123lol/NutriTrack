import XCTest
@testable import NutriTrack

final class SleepTimerTextTests: XCTestCase {
    private let utc = TimeZone(identifier: "UTC")!
    private let bedtime = Date(timeIntervalSince1970: 1_800_056_400)

    func testJustStartedSaysWhenAndToLeaveItOn() {
        let text = SleepTimerText.caption(startedAt: bedtime, now: bedtime.addingTimeInterval(600), timeZone: utc)
        XCTAssertEqual(text, "Sleep timer on since 23:40. Leave it on overnight: the morning check-in fills in your hours and switches it off.")
    }

    func testAfterANightSaysTheHoursAndPointsToTheCheckIn() {
        let text = SleepTimerText.caption(startedAt: bedtime, now: bedtime.addingTimeInterval(7.5 * 3600), timeZone: utc)
        XCTAssertEqual(text, "About 7 h 30 min since you went to bed. Do the check-in to save your sleep; it switches the moon off.")
        let whole = SleepTimerText.caption(startedAt: bedtime, now: bedtime.addingTimeInterval(8 * 3600 + 120), timeZone: utc)
        XCTAssertTrue(whole.hasPrefix("About 8 h since"))
    }

    func testTooLongIsIgnored() {
        let text = SleepTimerText.caption(startedAt: bedtime, now: bedtime.addingTimeInterval(15 * 3600), timeZone: utc)
        XCTAssertTrue(text.hasPrefix("The sleep timer has been on for more than 14 hours"))
    }
}
