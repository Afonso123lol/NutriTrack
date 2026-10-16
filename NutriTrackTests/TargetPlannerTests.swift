import XCTest
@testable import NutriTrack

final class TargetPlannerTests: XCTestCase {

    private func input(_ direction: GoalDirection, weight: Double = 138, height: Double = 180, sex: Sex = .male,
                       age: Int = 25, rate: Double = 0, tdee: Double = 3600) -> TargetInput {
        TargetInput(sex: sex, age: age, weightKg: weight, heightCm: height, direction: direction,
                    ratePercent: rate, tdee: tdee)
    }

    func testRateOptionsFollowBodyMassIndex() {
        XCTAssertEqual(TargetPlanner.rateOption(direction: .lose, bmi: 42), RateOption(defaultPercent: 0.5, maximumPercent: 1.0))
        XCTAssertEqual(TargetPlanner.rateOption(direction: .lose, bmi: 27), RateOption(defaultPercent: 0.5, maximumPercent: 0.75))
        XCTAssertEqual(TargetPlanner.rateOption(direction: .lose, bmi: 23), RateOption(defaultPercent: 0.35, maximumPercent: 0.5))
        XCTAssertNil(TargetPlanner.rateOption(direction: .lose, bmi: 18))
        XCTAssertEqual(TargetPlanner.rateOption(direction: .gain, bmi: 23), RateOption(defaultPercent: 0.25, maximumPercent: 0.5))
        XCTAssertNil(TargetPlanner.rateOption(direction: .gain, bmi: 26))
        XCTAssertNil(TargetPlanner.rateOption(direction: .maintain, bmi: 23))
    }

    func testDefaultLossForAHeavyPersonUsesHalfAPercentPerWeek() {
        let plan = TargetPlanner.plan(input(.lose))
        XCTAssertEqual(plan.direction, .lose)
        XCTAssertEqual(plan.limitedBy, .none)
        XCTAssertEqual(plan.calories, 3600 - 0.005 * 138 * 7700 / 7, accuracy: 0.5)
        XCTAssertEqual(plan.proteinG, 185)
        XCTAssertEqual(plan.fatG, plan.calories * 0.30 / 9, accuracy: 0.5)
        XCTAssertEqual(plan.calories, plan.proteinG * 4 + plan.fatG * 9 + plan.carbsG * 4, accuracy: 1)
    }

    func testDeficitIsCappedAtAShareOfExpenditure() {
        let heavy = TargetPlanner.plan(input(.lose, rate: 1.0))
        XCTAssertEqual(heavy.limitedBy, .deficitShare)
        XCTAssertEqual(heavy.calories, 3600 * 0.70, accuracy: 0.5)

        let lighter = TargetPlanner.plan(input(.lose, weight: 90, rate: 0.75, tdee: 3200))
        XCTAssertEqual(lighter.limitedBy, .none)
        XCTAssertEqual(lighter.calories, 3200 - 0.0075 * 90 * 7700 / 7, accuracy: 0.5)
    }

    func testRequestedRateAboveTheMaximumIsClamped() {
        let plan = TargetPlanner.plan(input(.lose, weight: 90, rate: 5, tdee: 4000))
        XCTAssertEqual(plan.calories, 4000 - 0.0075 * 90 * 7700 / 7, accuracy: 0.5)
    }

    func testDeficitCapIsTheSmallestOfThree() {
        let share = TargetPlanner.deficitCap(tdee: 3600, bmi: 42, fatMassKg: 57)
        XCTAssertEqual(share.limit, .deficitShare)
        XCTAssertEqual(share.kcal, 1080, accuracy: 0.001)
        let fat = TargetPlanner.deficitCap(tdee: 3400, bmi: 19, fatMassKg: 9)
        XCTAssertEqual(fat.limit, .fatMass)
        XCTAssertEqual(fat.kcal, 621, accuracy: 0.001)
        let absolute = TargetPlanner.deficitCap(tdee: 8000, bmi: 42, fatMassKg: 60)
        XCTAssertEqual(absolute.limit, .absoluteRate)
        XCTAssertEqual(absolute.kcal, 1650, accuracy: 0.001)
    }

    func testCalorieFloorWins() {
        let plan = TargetPlanner.plan(input(.lose, weight: 70, height: 160, sex: .female, age: 40, rate: 0.75, tdee: 1500))
        XCTAssertEqual(plan.limitedBy, .calorieFloor)
        XCTAssertGreaterThanOrEqual(plan.calories, 1200)
        XCTAssertGreaterThanOrEqual(plan.calories, 1500 * 0.75)
        XCTAssertGreaterThanOrEqual(plan.carbsG, 130)
    }

    func testLosingIsBlockedWhenUnderweightOrUnderage() {
        let thin = TargetPlanner.plan(input(.lose, weight: 55, height: 180, tdee: 2400))
        XCTAssertEqual(thin.direction, .maintain)
        XCTAssertEqual(thin.limitedBy, .blocked)
        XCTAssertEqual(thin.calories, 2400, accuracy: 0.5)
        XCTAssertEqual(TargetPlanner.plan(input(.lose, age: 17)).limitedBy, .blocked)
    }

    func testGainIsOnlyOfferedBelowBodyMassIndexTwentyFive() {
        XCTAssertEqual(TargetPlanner.plan(input(.gain)).limitedBy, .blocked)
        let plan = TargetPlanner.plan(input(.gain, weight: 70, height: 180, tdee: 2800))
        XCTAssertEqual(plan.direction, .gain)
        XCTAssertEqual(plan.calories, 2800 + 0.0025 * 70 * 7700 / 7, accuracy: 0.5)
        let fast = TargetPlanner.plan(input(.gain, weight: 70, height: 180, rate: 0.5, tdee: 1800))
        XCTAssertEqual(fast.limitedBy, .surplusShare)
        XCTAssertEqual(fast.calories, 1800 * 1.15, accuracy: 0.5)
    }

    func testProteinFollowsFatFreeMassWithFloorAndCap() {
        let maintain = TargetPlanner.plan(input(.maintain, weight: 80, height: 180, tdee: 2800))
        XCTAssertEqual(maintain.proteinG, 125)
        let floor = max(1.5 * BodyMetrics.fatFreeMass(sex: .male, weightKg: 80, heightCm: 180), 1.2 * 80)
        XCTAssertEqual(maintain.proteinFloorG, floor, accuracy: 0.01)
        XCTAssertEqual(maintain.proteinG.truncatingRemainder(dividingBy: 5), 0)
    }

    func testFatHasAFloorAndCarbsTakeTheRest() {
        let plan = TargetPlanner.plan(input(.maintain, weight: 80, height: 180, tdee: 2800))
        XCTAssertEqual(plan.fatFloorG, max(2800 * 0.20 / 9, 0.5 * 80), accuracy: 0.01)
        XCTAssertEqual(plan.fatG, 2800 * 0.30 / 9, accuracy: 0.5)
        XCTAssertEqual(plan.carbsG, (2800 - plan.proteinG * 4 - plan.fatG * 9) / 4, accuracy: 0.5)
    }

    func testCaloriesOverrideRecomputesTheMacros() {
        let plan = TargetPlanner.plan(input(.lose), calories: 3200)
        XCTAssertEqual(plan.calories, 3200)
        XCTAssertEqual(plan.fatG, 3200 * 0.30 / 9, accuracy: 0.5)
    }

    func testCarbMinimumFollowsTheMinutesOfTheDay() {
        func easy(_ minutes: Double) -> Double {
            TargetPlanner.carbMinimum(referenceWeightKg: 81, trainingMinutes: minutes, hardEffort: false)
        }
        XCTAssertEqual(easy(0), 3 * 81)
        XCTAssertEqual(easy(29), 3 * 81)
        XCTAssertEqual(easy(30), 4 * 81)
        XCTAssertEqual(easy(89), 4 * 81)
        XCTAssertEqual(easy(90), 5 * 81)
        XCTAssertEqual(easy(179), 5 * 81)
        XCTAssertEqual(easy(180), 6 * 81)
        XCTAssertEqual(easy(300), 6 * 81)
    }

    func testCarbMinimumIsHigherWithModerateOrHardEffort() {
        func hard(_ minutes: Double) -> Double {
            TargetPlanner.carbMinimum(referenceWeightKg: 81, trainingMinutes: minutes, hardEffort: true)
        }
        XCTAssertEqual(hard(20), 3 * 81)
        XCTAssertEqual(hard(45), 5 * 81)
        XCTAssertEqual(hard(120), 6 * 81)
        XCTAssertEqual(hard(200), 6 * 81)
        XCTAssertEqual(hard(239), 6 * 81)
        XCTAssertEqual(hard(240), 8 * 81)
    }

    func testTrainingDayLowersFatToMakeRoomForCarbs() {
        let plan = TargetPlanner.plan(input(.maintain, weight: 80, height: 180, tdee: 2800))
        let same = TargetPlanner.dayMacros(plan, carbMinimumG: plan.carbsG - 20)
        XCTAssertEqual(same.carbsG, plan.carbsG)
        XCTAssertFalse(same.isShort)

        let more = TargetPlanner.dayMacros(plan, carbMinimumG: plan.carbsG + 45)
        XCTAssertEqual(more.carbsG, plan.carbsG + 45, accuracy: 0.01)
        XCTAssertEqual(more.fatG, plan.fatG - 20, accuracy: 0.01)
        XCTAssertFalse(more.isShort)

        let short = TargetPlanner.dayMacros(plan, carbMinimumG: plan.carbsG + 400)
        XCTAssertEqual(short.fatG, plan.fatFloorG, accuracy: 0.01)
        XCTAssertTrue(short.isShort)
    }

    func testWeeklyChangeIsLimited() {
        XCTAssertEqual(TargetPlanner.limitWeeklyChange(2000, previous: 2400), 2250)
        XCTAssertEqual(TargetPlanner.limitWeeklyChange(2600, previous: 2400), 2550)
        XCTAssertEqual(TargetPlanner.limitWeeklyChange(2450, previous: 2400), 2450)
        XCTAssertEqual(TargetPlanner.limitWeeklyChange(2000, previous: nil), 2000)
    }

    func testSafeguardsReactToTheMeasuredRate() {
        XCTAssertEqual(TargetPlanner.safeguard(lossKgPerWeek: [1.2, 1.1, 1.3], weightKg: 100), .raise)
        XCTAssertEqual(TargetPlanner.safeguard(lossKgPerWeek: [0.8, 1.1, 1.3], weightKg: 100), .none)
        XCTAssertEqual(TargetPlanner.safeguard(lossKgPerWeek: [1.1, 1.3], weightKg: 100), .none)
        XCTAssertEqual(TargetPlanner.safeguard(lossKgPerWeek: [0.5, 1.6, 1.7], weightKg: 100), .maintenance)
        XCTAssertEqual(TargetPlanner.safeguard(lossKgPerWeek: [1.6, 1.2, 1.7], weightKg: 200), .none)
        XCTAssertEqual(TargetPlanner.safeguard(lossKgPerWeek: [], weightKg: 100), .none)
    }
}
