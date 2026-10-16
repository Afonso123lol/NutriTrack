import XCTest
@testable import NutriTrack

final class DayStateBoardTests: XCTestCase {

    private func entry(energy: Int = 4, soreness: Int = 2, stress: Int = 2, sick: Bool = false,
                       pain: Bool = false) -> DayStateBoard.Entry {
        DayStateBoard.Entry(energy: energy, soreness: soreness, stress: stress, isSick: sick, hasPain: pain)
    }

    private func board(today: DayStateBoard.Entry, history: [DayStateBoard.Entry], sleep: Double? = 7.5,
                       need: Double = 8) -> DayStateBoard {
        DayStateBoard.make(today: today, history: history, sleepHours: sleep, sleepNeed: need)
    }

    func testWithoutFourteenDaysOnlyTodayIsShown() {
        let result = board(today: entry(energy: 3), history: Array(repeating: entry(), count: 6))
        let energy = result.rows[0]
        XCTAssertEqual(energy.valueText, "Energy · 3 of 5")
        XCTAssertNil(energy.usual)
        XCTAssertNil(energy.band)
        XCTAssertEqual(result.footer, "Still learning your usual: 6 of 14 days")
    }

    func testSickDaysStayOutOfTheUsual() {
        let history = Array(repeating: entry(energy: 4), count: 14) + Array(repeating: entry(energy: 1, sick: true), count: 5)
        let result = board(today: entry(energy: 4), history: history)
        XCTAssertEqual(result.rows[0].usual, 4)
        XCTAssertEqual(result.footer, "Baseline: 14 of 28 days")
    }

    func testTheFiveBandsWithAFloorOfOneLevel() {
        let steady = Array(repeating: entry(energy: 3), count: 14)
        XCTAssertEqual(board(today: entry(energy: 3), history: steady).rows[0].band, .within)
        XCTAssertEqual(board(today: entry(energy: 2), history: steady).rows[0].band, .below)
        XCTAssertEqual(board(today: entry(energy: 1), history: steady).rows[0].band, .wellBelow)
        XCTAssertEqual(board(today: entry(energy: 4), history: steady).rows[0].band, .above)
        XCTAssertEqual(board(today: entry(energy: 5), history: steady).rows[0].band, .wellAbove)
    }

    func testAWideSpreadNeedsABiggerGap() {
        let wide = Array(repeating: entry(energy: 1), count: 7) + Array(repeating: entry(energy: 5), count: 7)
        XCTAssertEqual(board(today: entry(energy: 2), history: wide).rows[0].band, .within)
    }

    func testOnlyTheUnfavourableDirectionWarns() {
        let steady = Array(repeating: entry(energy: 3, soreness: 2, stress: 2), count: 14)
        let low = board(today: entry(energy: 2, soreness: 1, stress: 1), history: steady)
        XCTAssertTrue(low.rows[0].isUnfavourable)
        XCTAssertFalse(low.rows[1].isUnfavourable)
        XCTAssertFalse(low.rows[2].isUnfavourable)
        let high = board(today: entry(energy: 4, soreness: 4, stress: 4), history: steady)
        XCTAssertFalse(high.rows[0].isUnfavourable)
        XCTAssertTrue(high.rows[1].isUnfavourable)
        XCTAssertTrue(high.rows[2].isUnfavourable)
    }

    func testTextsMatchTheMockup() {
        let history = Array(repeating: entry(energy: 4, soreness: 2, stress: 2), count: 19)
        let result = board(today: entry(energy: 3, soreness: 2, stress: 4), history: history, sleep: 5.5)
        XCTAssertEqual(result.rows.map(\.valueText), ["Energy · 3 of 5", "Soreness · 2 of 5", "Stress · 4 of 5"])
        XCTAssertEqual(result.rows.map(\.usualText), ["usually 4", "usually 2", "usually 2"])
        XCTAssertEqual(result.rows.map(\.bandText), ["↓ Below your usual", "Within your usual", "↑ Well above your usual"])
        XCTAssertEqual(result.sleep?.valueText, "Sleep · 5.5 h")
        XCTAssertEqual(result.sleep?.needText, "need 8 h")
        XCTAssertEqual(result.sleep?.isShort, true)
        XCTAssertEqual(result.sleep?.fraction ?? 0, 5.5 / 8, accuracy: 0.0001)
        XCTAssertEqual(result.footer, "Baseline: 19 of 28 days")
    }

    func testSleepIsCappedAtTheNeedAndNotPenalisedForMore() {
        let result = board(today: entry(), history: [], sleep: 9.5, need: 8)
        XCTAssertEqual(result.sleep?.fraction, 1)
        XCTAssertEqual(result.sleep?.isShort, false)
        XCTAssertNil(board(today: entry(), history: [], sleep: nil).sleep)
        XCTAssertNil(board(today: entry(), history: [], sleep: 0).sleep)
    }

    func testOldRecordsWithoutSorenessDoNotCountForSoreness() {
        let old = Array(repeating: entry(energy: 4, soreness: 0, stress: 0), count: 20)
        let result = board(today: entry(energy: 4, soreness: 3, stress: 3), history: old)
        XCTAssertEqual(result.rows[0].usual, 4)
        XCTAssertNil(result.rows[1].usual)
        XCTAssertNil(result.rows[2].usual)
    }

    func testIllAndPainShowOnlyWhenMarked() {
        XCTAssertFalse(board(today: entry(), history: []).isIll)
        XCTAssertTrue(board(today: entry(sick: true), history: []).isIll)
        XCTAssertTrue(board(today: entry(pain: true), history: []).hasPain)
    }
}
