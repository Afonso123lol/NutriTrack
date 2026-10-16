import XCTest
@testable import NutriTrack

final class WeekPathTests: XCTestCase {

    private let plan: [Double] = [25, 0, 25, 0, 0, 25, 0]

    func testDaysAreCumulative() {
        let path = WeekPath.make(plannedByDay: plan, doneByDay: [25, 0, 25, 0, 0, 0, 0], todayIndex: 3)
        XCTAssertEqual(path.days.map(\.planned), [25, 25, 50, 50, 50, 75, 75])
        XCTAssertEqual(path.days.map(\.done), [25, 25, 50, 50, 50, 50, 50])
        XCTAssertEqual(path.days.map(\.hasSession), [true, false, true, false, false, true, false])
        XCTAssertEqual(path.totalPlanned, 75)
        XCTAssertEqual(path.doneSoFar, 50)
    }

    func testOnPathWhileTodaysSessionIsStillToDo() {
        let path = WeekPath.make(plannedByDay: plan, doneByDay: [25, 0, 0, 0, 0, 0, 0], todayIndex: 2)
        XCTAssertEqual(path.status, .onPath)
    }

    func testOnPathAfterDoingTodaysSession() {
        let path = WeekPath.make(plannedByDay: plan, doneByDay: [25, 0, 25, 0, 0, 0, 0], todayIndex: 2)
        XCTAssertEqual(path.status, .onPath)
    }

    func testBehindAfterMissingASession() {
        let path = WeekPath.make(plannedByDay: plan, doneByDay: [25, 0, 25, 0, 0, 0, 0], todayIndex: 6)
        XCTAssertEqual(path.status, .behind)
    }

    func testSlightlyShortIsStillOnPath() {
        let path = WeekPath.make(plannedByDay: plan, doneByDay: [22, 0, 0, 0, 0, 0, 0], todayIndex: 1)
        XCTAssertEqual(path.status, .onPath)
    }

    func testAheadWhenWellOverThePlan() {
        let path = WeekPath.make(plannedByDay: plan, doneByDay: [40, 20, 0, 0, 0, 0, 0], todayIndex: 1)
        XCTAssertEqual(path.status, .ahead)
    }

    func testAnEmptyWeekIsOnPath() {
        let path = WeekPath.make(plannedByDay: [], doneByDay: [], todayIndex: 9)
        XCTAssertEqual(path.days.count, 7)
        XCTAssertEqual(path.todayIndex, 6)
        XCTAssertEqual(path.status, .onPath)
        XCTAssertEqual(path.totalPlanned, 0)
    }

    func testBandAroundThePlan() {
        let path = WeekPath.make(plannedByDay: plan, doneByDay: [], todayIndex: 0)
        XCTAssertEqual(path.lower(at: 5), 75 * 0.85, accuracy: 0.0001)
        XCTAssertEqual(path.upper(at: 5), 75 * 1.10, accuracy: 0.0001)
    }

    func testLabels() {
        XCTAssertEqual(WeekPath.Status.onPath.label, "On your path")
        XCTAssertEqual(WeekPath.Status.behind.label, "A little behind")
        XCTAssertEqual(WeekPath.Status.ahead.label, "Ahead of plan")
    }
}
