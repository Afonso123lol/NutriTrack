import XCTest
@testable import NutriTrack

final class TrainingPlannerTests: XCTestCase {

    private func week(planned: Double, done: Double, block: Int = 1, weekInBlock: Int = 1,
                      deload: Bool = false, badDays: Int = 0) -> WeekSummary {
        WeekSummary(plannedMinutes: planned, doneMinutes: done, isDeload: deload, badDays: badDays,
                    blockIndex: block, weekInBlock: weekInBlock)
    }

    private func input(days: Int = 3, declared: Double = 0, bmi: Double = 32, history: [WeekSummary] = [],
                       weeksSinceStart: Int? = nil, gap: Int? = nil, recent: [Double] = [],
                       longest: Double = 0, treadmill: Bool = false, bike: Bool = false,
                       strength: Bool = true) -> PlannerInput {
        PlannerInput(daysPerWeek: days, declaredWeeklyMinutes: declared, bmi: bmi, hasTreadmill: treadmill,
                     hasBike: bike, allowsStrength: strength, history: history,
                     weeksSinceStart: weeksSinceStart ?? history.count, daysSinceLastSession: gap,
                     recentDoneMinutes: recent, longestSessionLast30Days: longest)
    }

    private func aerobic(_ plan: WeekPlan) -> [SessionPlan] { plan.sessions.filter { $0.kind != .strength } }
    private func strength(_ plan: WeekPlan) -> [SessionPlan] { plan.sessions.filter { $0.kind == .strength } }

    func testTrainingAndStrengthDays() {
        XCTAssertEqual(TrainingPlanner.trainingDays(3), [0, 2, 5])
        XCTAssertEqual(TrainingPlanner.trainingDays(4), [0, 1, 3, 5])
        XCTAssertEqual(TrainingPlanner.trainingDays(5), [0, 1, 3, 4, 5])
        XCTAssertEqual(TrainingPlanner.trainingDays(6), [0, 1, 2, 3, 4, 5])
        XCTAssertEqual(TrainingPlanner.trainingDays(1), [0, 2, 5])
        XCTAssertEqual(TrainingPlanner.trainingDays(9), [0, 1, 2, 3, 4, 5])
        XCTAssertEqual(TrainingPlanner.strengthDays(3), [0, 2])
        XCTAssertEqual(TrainingPlanner.strengthDays(5), [0, 3])
    }

    func testStrengthSetsGrowWithTheWeeks() {
        XCTAssertEqual([1, 2, 3, 6, 7, 20].map { TrainingPlanner.strengthSets(weekNumber: $0, isDeload: false) },
                       [1, 1, 2, 2, 3, 3])
        XCTAssertEqual(TrainingPlanner.strengthSets(weekNumber: 1, isDeload: true), 1)
        XCTAssertEqual(TrainingPlanner.strengthSets(weekNumber: 9, isDeload: true), 2)
    }

    func testFirstPlanForASedentaryBeginner() {
        let plan = TrainingPlanner.nextWeek(input())
        XCTAssertEqual(plan.decision, .start)
        XCTAssertEqual(plan.phase, .transition)
        XCTAssertEqual(plan.blockIndex, 1)
        XCTAssertEqual(plan.weekInBlock, 1)
        XCTAssertFalse(plan.isDeload)
        XCTAssertEqual(plan.targetMinutes, 75)
        XCTAssertEqual(aerobic(plan).map(\.dayIndex), [0, 2, 5])
        XCTAssertEqual(aerobic(plan).map(\.targetMinutes), [25, 25, 25])
        XCTAssertTrue(aerobic(plan).allSatisfy { $0.kind == .easy && $0.modality == .walk })
        XCTAssertEqual(strength(plan).map(\.dayIndex), [0, 2])
        XCTAssertEqual(strength(plan).map(\.strengthSets), [1, 1])
    }

    func testFirstPlanUsesDeclaredMinutesWithinLimits() {
        let plan = TrainingPlanner.nextWeek(input(days: 4, declared: 240, bmi: 24))
        XCTAssertEqual(aerobic(plan).map(\.targetMinutes), [60, 60, 60, 65])
        XCTAssertEqual(aerobic(plan).last?.kind, .long)
        XCTAssertEqual(aerobic(plan).last?.dayIndex, 5)
        XCTAssertEqual(plan.targetMinutes, 245)
        XCTAssertEqual(strength(plan).map(\.dayIndex), [0, 3])
        XCTAssertEqual(TrainingPlanner.nextWeek(input(days: 6, declared: 900, bmi: 24)).targetMinutes, 480)
    }

    func testFirstPlanPrefersWhatWasActuallyLogged() {
        let plan = TrainingPlanner.nextWeek(input(declared: 300, recent: [100, 120, 0, 140]))
        XCTAssertEqual(plan.targetMinutes, 90)
    }

    func testSmallVolumesGrowFiveMinutesPerSession() {
        let plan = TrainingPlanner.nextWeek(input(history: [week(planned: 75, done: 75)]))
        XCTAssertEqual(plan.decision, .progress)
        XCTAssertEqual(plan.basisMinutes, 75)
        XCTAssertEqual(plan.targetMinutes, 90)
        XCTAssertEqual(plan.weekInBlock, 2)
        XCTAssertEqual(plan.blockIndex, 1)
    }

    func testThirdWeekIsADeloadForAHeavyBeginner() {
        let history = [week(planned: 75, done: 75), week(planned: 90, done: 90, weekInBlock: 2)]
        let plan = TrainingPlanner.nextWeek(input(history: history))
        XCTAssertEqual(plan.decision, .deload)
        XCTAssertTrue(plan.isDeload)
        XCTAssertEqual(plan.weekInBlock, 3)
        XCTAssertEqual(aerobic(plan).map(\.targetMinutes), [15, 15, 15])
        XCTAssertEqual(strength(plan).map(\.strengthSets), [1, 1])
    }

    func testAfterADeloadTheBlockRestartsAtItsSecondWeek() {
        let history = [week(planned: 75, done: 75), week(planned: 90, done: 90, weekInBlock: 2),
                       week(planned: 45, done: 45, weekInBlock: 3, deload: true)]
        let plan = TrainingPlanner.nextWeek(input(history: history))
        XCTAssertEqual(plan.decision, .afterDeload)
        XCTAssertEqual(plan.targetMinutes, 90)
        XCTAssertEqual(plan.blockIndex, 2)
        XCTAssertEqual(plan.weekInBlock, 1)
    }

    func testLeanTrainedAthleteUsesAFourWeekCycleInBase() {
        let history = [week(planned: 180, done: 180), week(planned: 189, done: 189, weekInBlock: 2)]
        let plan = TrainingPlanner.nextWeek(input(bmi: 24, history: history, weeksSinceStart: 10))
        XCTAssertEqual(plan.phase, .base)
        XCTAssertEqual(plan.decision, .progress)
        XCTAssertFalse(plan.isDeload)
        XCTAssertEqual(plan.weekInBlock, 3)
    }

    func testLargerVolumesGrowFivePercentFromWhatWasDone() {
        let full = TrainingPlanner.nextWeek(input(bmi: 24, history: [week(planned: 180, done: 180)], weeksSinceStart: 10))
        XCTAssertEqual(full.basisMinutes, 180)
        XCTAssertEqual(full.targetMinutes, 195)

        let partial = TrainingPlanner.nextWeek(input(bmi: 24, history: [week(planned: 200, done: 180)], weeksSinceStart: 10))
        XCTAssertEqual(partial.decision, .progress)
        XCTAssertEqual(partial.basisMinutes, 180)

        let extra = TrainingPlanner.nextWeek(input(bmi: 24, history: [week(planned: 180, done: 260)], weeksSinceStart: 10))
        XCTAssertEqual(extra.basisMinutes, 180)
    }

    func testMiddlingAdherenceRepeatsTheWeek() {
        let plan = TrainingPlanner.nextWeek(input(bmi: 24, history: [week(planned: 180, done: 135)], weeksSinceStart: 10))
        XCTAssertEqual(plan.decision, .repeatWeek)
        XCTAssertEqual(plan.targetMinutes, 180)
        XCTAssertFalse(plan.suggestsFewerDays)
    }

    func testOneLowWeekRepeatsAndTwoLowWeeksReduceThePlan() {
        let one = TrainingPlanner.nextWeek(input(bmi: 24, history: [week(planned: 180, done: 90)], weeksSinceStart: 10))
        XCTAssertEqual(one.decision, .repeatWeek)

        let history = [week(planned: 180, done: 90), week(planned: 180, done: 100, weekInBlock: 2)]
        let two = TrainingPlanner.nextWeek(input(bmi: 24, history: history, weeksSinceStart: 10))
        XCTAssertEqual(two.decision, .reduce)
        XCTAssertEqual(two.targetMinutes, 90)
        XCTAssertTrue(two.suggestsFewerDays)
    }

    func testThreeLowReadinessDaysRepeatWithoutProgress() {
        let plan = TrainingPlanner.nextWeek(input(bmi: 24, history: [week(planned: 180, done: 180, badDays: 3)],
                                                  weeksSinceStart: 10))
        XCTAssertEqual(plan.decision, .lowReadiness)
        XCTAssertEqual(plan.targetMinutes, 180)
    }

    func testGapsLowerTheVolume() {
        let history = [week(planned: 180, done: 180)]
        let short = TrainingPlanner.nextWeek(input(bmi: 24, history: history, weeksSinceStart: 10, gap: 10))
        XCTAssertEqual(short.decision, .returnAfterOneWeek)
        XCTAssertEqual(short.targetMinutes, 150)
        XCTAssertEqual(short.blockIndex, 2)
        XCTAssertEqual(short.weekInBlock, 1)

        let long = TrainingPlanner.nextWeek(input(bmi: 24, history: history, weeksSinceStart: 10, gap: 20))
        XCTAssertEqual(long.decision, .returnAfterTwoWeeks)
        XCTAssertEqual(long.targetMinutes, 120)

        let restart = TrainingPlanner.nextWeek(input(bmi: 24, history: history, weeksSinceStart: 10, gap: 30))
        XCTAssertEqual(restart.decision, .restart)
        XCTAssertEqual(restart.targetMinutes, 90)
        XCTAssertEqual(restart.phase, .transition)
        XCTAssertEqual(strength(restart).map(\.strengthSets), [1, 1])
    }

    func testNoSessionGoesAboveTheRecentLongestByMoreThanTenPercent() {
        let plan = TrainingPlanner.nextWeek(input(days: 4, declared: 240, bmi: 24, longest: 40))
        XCTAssertTrue(aerobic(plan).allSatisfy { $0.targetMinutes <= 45 })
        XCTAssertEqual(plan.targetMinutes, 180)
    }

    func testModalitiesFollowTheEquipmentAndThePhase() {
        let transition = TrainingPlanner.nextWeek(input(days: 5, declared: 300, bmi: 24, treadmill: true, bike: true))
        XCTAssertEqual(aerobic(transition).map(\.modality), [.walk, .incline, .bike, .walk, .walk])
        let base = TrainingPlanner.nextWeek(input(days: 5, bmi: 24, history: [week(planned: 300, done: 300)],
                                                  weeksSinceStart: 10, treadmill: true, bike: true))
        XCTAssertEqual(aerobic(base).last?.modality, .hike)
    }

    func testStrengthCanBeWithheld() {
        let plan = TrainingPlanner.nextWeek(input(strength: false))
        XCTAssertTrue(strength(plan).isEmpty)
        XCTAssertEqual(plan.strengthSets, 0)
    }
}
