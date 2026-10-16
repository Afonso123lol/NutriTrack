import XCTest
@testable import NutriTrack

final class PendingMealTextTests: XCTestCase {

    private let start = Date(timeIntervalSince1970: 1_000_000)

    func testElapsedUnderAMinute() {
        XCTAssertEqual(PendingMealText.elapsed(since: start, now: start.addingTimeInterval(40)), "Sent just now")
    }

    func testElapsedInMinutes() {
        XCTAssertEqual(PendingMealText.elapsed(since: start, now: start.addingTimeInterval(3 * 60 + 10)), "Sent 3 min ago")
    }

    func testElapsedInHours() {
        XCTAssertEqual(PendingMealText.elapsed(since: start, now: start.addingTimeInterval(3600)), "Sent 1 h ago")
        XCTAssertEqual(PendingMealText.elapsed(since: start, now: start.addingTimeInterval(3600 + 20 * 60)), "Sent 1 h 20 min ago")
    }

    func testElapsedNeverGoesNegative() {
        XCTAssertEqual(PendingMealText.elapsed(since: start, now: start.addingTimeInterval(-90)), "Sent just now")
    }

    func testFirstAttemptIsWaiting() {
        XCTAssertEqual(PendingMealText.waiting(attempt: nil), "Waiting for the answer")
        XCTAssertEqual(PendingMealText.waiting(attempt: 0), "Waiting for the answer")
    }

    func testLaterAttemptsSayWhichOne() {
        XCTAssertEqual(PendingMealText.waiting(attempt: 1), "Retrying · attempt 2")
        XCTAssertEqual(PendingMealText.waiting(attempt: 4), "Retrying · attempt 5")
    }
}
