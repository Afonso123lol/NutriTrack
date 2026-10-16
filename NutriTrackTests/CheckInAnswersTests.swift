import XCTest
@testable import NutriTrack

final class CheckInAnswersTests: XCTestCase {

    private func answers(energy: Int = 4, quality: Int = 3, soreness: Int = 2, stress: Int = 1) -> CheckInAnswers {
        var result = CheckInAnswers(wakeTime: Date(timeIntervalSince1970: 1_790_000_000))
        result.energy = energy
        result.quality = quality
        result.soreness = soreness
        result.stress = stress
        return result
    }

    func testStartsIncompleteWithSevenAndAHalfHours() {
        let fresh = CheckInAnswers(wakeTime: Date(timeIntervalSince1970: 1_790_000_000))
        XCTAssertFalse(fresh.isComplete)
        XCTAssertEqual(fresh.sleepHours, 7.5)
        XCTAssertFalse(fresh.isSick)
        XCTAssertFalse(fresh.hasPain)
    }

    func testCompleteNeedsTheFourScales() {
        XCTAssertTrue(answers().isComplete)
        XCTAssertFalse(answers(energy: 0).isComplete)
        XCTAssertFalse(answers(quality: 0).isComplete)
        XCTAssertFalse(answers(soreness: 0).isComplete)
        XCTAssertFalse(answers(stress: 0).isComplete)
        XCTAssertFalse(answers(stress: 6).isComplete)
    }
}
