import XCTest
@testable import NutriTrack

final class TrainingLoadTests: XCTestCase {

    private func session(_ minutes: Double, rpe: Int = 3, strength: Bool = false, elevation: Double = 0) -> LoggedSession {
        LoggedSession(isStrength: strength, durationMin: minutes, rpe: rpe, elevationGainM: elevation)
    }

    func testWeekTotals() {
        let load = TrainingLoad.summarize(week: [session(30), session(45, rpe: 4, elevation: 200), session(25, rpe: 5, strength: true)],
                                          previousWeekMinutes: nil, twoWeeksAgoMinutes: nil, longestBefore: 0)
        XCTAssertEqual(load.aerobicMinutes, 75)
        XCTAssertEqual(load.load, 395)
        XCTAssertEqual(load.elevationM, 200)
        XCTAssertEqual(load.sessions, 3)
        XCTAssertTrue(load.warnings.isEmpty)
    }

    func testWeeklyJumpWarnings() {
        let week = [session(60), session(60), session(60)]
        XCTAssertTrue(TrainingLoad.summarize(week: week, previousWeekMinutes: 170, twoWeeksAgoMinutes: 160, longestBefore: 60).warnings.isEmpty)
        XCTAssertEqual(TrainingLoad.summarize(week: week, previousWeekMinutes: 150, twoWeeksAgoMinutes: 150, longestBefore: 60).warnings,
                       [.weeklyJump(percent: 20)])
        XCTAssertEqual(TrainingLoad.summarize(week: week, previousWeekMinutes: 150, twoWeeksAgoMinutes: 120, longestBefore: 60).warnings,
                       [.twoWeekJump(percent: 50)])
        XCTAssertTrue(TrainingLoad.summarize(week: week, previousWeekMinutes: 0, twoWeeksAgoMinutes: nil, longestBefore: 60).warnings.isEmpty)
    }

    func testSessionPeakAndLongShareWarnings() {
        let peak = TrainingLoad.summarize(week: [session(70)], previousWeekMinutes: nil, twoWeeksAgoMinutes: nil, longestBefore: 60)
        XCTAssertEqual(peak.warnings, [.sessionPeak(minutes: 70)])
        XCTAssertTrue(TrainingLoad.summarize(week: [session(66)], previousWeekMinutes: nil, twoWeeksAgoMinutes: nil, longestBefore: 60).warnings.isEmpty)

        let lopsided = [session(30), session(30), session(30), session(90)]
        XCTAssertEqual(TrainingLoad.summarize(week: lopsided, previousWeekMinutes: nil, twoWeeksAgoMinutes: nil, longestBefore: 0).warnings,
                       [.longShare(percent: 50)])
        XCTAssertTrue(TrainingLoad.summarize(week: [session(30), session(30), session(90)], previousWeekMinutes: nil,
                                             twoWeeksAgoMinutes: nil, longestBefore: 0).warnings.isEmpty)
    }

    func testExercisesDependOnEquipment() {
        let gym = StrengthProgram.exercises(hasGym: true)
        let home = StrengthProgram.exercises(hasGym: false)
        XCTAssertEqual(gym.count, 6)
        XCTAssertEqual(home.count, 6)
        XCTAssertEqual(Set(gym.map(\.pattern)), Set(home.map(\.pattern)))
        XCTAssertEqual(Set(gym.map(\.key)).count, 6)
        XCTAssertTrue(gym.contains { $0.usesLoad })
        XCTAssertNotNil(StrengthProgram.exercise(key: gym[0].key))
    }

    func testRepsInReserveTargetsEaseAfterTheFirstMonth() {
        XCTAssertEqual(StrengthProgram.targetReserve(weekNumber: 1), 3...4)
        XCTAssertEqual(StrengthProgram.targetReserve(weekNumber: 4), 3...4)
        XCTAssertEqual(StrengthProgram.targetReserve(weekNumber: 5), 2...3)
    }

    func testDoubleProgression() {
        let reserve = 2...3
        XCTAssertEqual(StrengthProgram.next(after: [], reserve: reserve, usesLoad: true), .hold)
        XCTAssertEqual(StrengthProgram.next(after: [SetResult(loadKg: 20, reps: 12, rir: 3)], reserve: reserve, usesLoad: true), .addRep)
        XCTAssertEqual(StrengthProgram.next(after: [SetResult(loadKg: 20, reps: 15, rir: 3), SetResult(loadKg: 20, reps: 15, rir: 2)],
                                            reserve: reserve, usesLoad: true), .addLoad(kg: 21))
        XCTAssertEqual(StrengthProgram.next(after: [SetResult(loadKg: 20, reps: 15, rir: 1)], reserve: reserve, usesLoad: true), .addRep)
        XCTAssertEqual(StrengthProgram.next(after: [SetResult(loadKg: 4, reps: 15, rir: 2)], reserve: reserve, usesLoad: true), .addLoad(kg: 4.5))
        XCTAssertEqual(StrengthProgram.next(after: [SetResult(loadKg: 20, reps: 11, rir: 5)], reserve: reserve, usesLoad: true), .addLoad(kg: 21))
        XCTAssertEqual(StrengthProgram.next(after: [SetResult(loadKg: 0, reps: 15, rir: 2)], reserve: reserve, usesLoad: false), .harderVariation)
    }

    func testEstimatedOneRepMaxOnlyForShortSets() {
        XCTAssertEqual(StrengthProgram.estimatedOneRepMax(loadKg: 100, reps: 5) ?? 0, 116.67, accuracy: 0.01)
        XCTAssertNil(StrengthProgram.estimatedOneRepMax(loadKg: 100, reps: 12))
        XCTAssertNil(StrengthProgram.estimatedOneRepMax(loadKg: 0, reps: 5))
    }
}
