import XCTest
@testable import NutriTrack

final class WeighInClassifierTests: XCTestCase {

    private let calendar = Calendar.current
    private let base = Date(timeIntervalSince1970: 1_800_000_000)

    private func at(_ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: base)!
    }

    private func session(_ hour: Int, _ minute: Int, minutes: Double) -> DateInterval {
        DateInterval(start: at(hour, minute), duration: minutes * 60)
    }

    func testBeforeTheFirstMealAndSoonAfterWakingIsFasted() {
        let context = WeighInClassifier.context(at: at(8), wokeAt: at(7, 30), firstMealAt: at(9), sessions: [])
        XCTAssertEqual(context, .fasted)
    }

    func testWeighingBeforeTheCheckInStillCountsAsFasted() {
        let context = WeighInClassifier.context(at: at(7), wokeAt: at(7, 30), firstMealAt: nil, sessions: [])
        XCTAssertEqual(context, .fasted)
    }

    func testAfterTheFirstMealIsDaytime() {
        let context = WeighInClassifier.context(at: at(9, 30), wokeAt: at(7, 30), firstMealAt: at(9), sessions: [])
        XCTAssertEqual(context, .daytime)
    }

    func testMoreThanThreeHoursAfterWakingIsDaytimeEvenWithoutAMeal() {
        let context = WeighInClassifier.context(at: at(11), wokeAt: at(7, 30), firstMealAt: nil, sessions: [])
        XCTAssertEqual(context, .daytime)
    }

    func testWithoutAWakeTimeTheMorningEndsAtEleven() {
        XCTAssertEqual(WeighInClassifier.context(at: at(9), wokeAt: nil, firstMealAt: nil, sessions: []), .fasted)
        XCTAssertEqual(WeighInClassifier.context(at: at(11), wokeAt: nil, firstMealAt: nil, sessions: []), .daytime)
    }

    func testDuringAndUpToThreeHoursAfterASessionIsAfterTraining() {
        let sessions = [session(18, 30, minutes: 45)]
        XCTAssertEqual(WeighInClassifier.context(at: at(19), wokeAt: at(7), firstMealAt: at(8), sessions: sessions),
                       .afterTraining)
        XCTAssertEqual(WeighInClassifier.context(at: at(22), wokeAt: at(7), firstMealAt: at(8), sessions: sessions),
                       .afterTraining)
        XCTAssertEqual(WeighInClassifier.context(at: at(22, 30), wokeAt: at(7), firstMealAt: at(8), sessions: sessions),
                       .daytime)
    }

    func testWeighingAsTheSessionStartsStillCountsAsBeforeTraining() {
        let sessions = [session(18, 30, minutes: 45)]
        XCTAssertEqual(WeighInClassifier.context(at: at(18, 40), wokeAt: at(7), firstMealAt: at(8), sessions: sessions),
                       .daytime)
        XCTAssertEqual(WeighInClassifier.context(at: at(18, 45), wokeAt: at(7), firstMealAt: at(8), sessions: sessions),
                       .daytime)
        XCTAssertEqual(WeighInClassifier.context(at: at(18, 46), wokeAt: at(7), firstMealAt: at(8), sessions: sessions),
                       .afterTraining)
    }

    func testBeforeTheSessionIsNotAfterTraining() {
        let sessions = [session(18, 30, minutes: 45)]
        XCTAssertEqual(WeighInClassifier.context(at: at(18), wokeAt: at(7), firstMealAt: at(8), sessions: sessions),
                       .daytime)
    }

    func testAfterTrainingWinsOverFasted() {
        let sessions = [session(6, 30, minutes: 30)]
        XCTAssertEqual(WeighInClassifier.context(at: at(7, 30), wokeAt: at(6), firstMealAt: nil, sessions: sessions),
                       .afterTraining)
    }
}
