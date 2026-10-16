import XCTest
@testable import NutriTrack

final class HealthScoresTests: XCTestCase {

    private func date(hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 1
        components.day = 1
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components)!
    }

    private func assertWeightsSumToOne(_ score: HealthScore, file: StaticString = #filePath, line: UInt = #line) {
        let sum = score.components.reduce(0) { $0 + $1.weight }
        XCTAssertEqual(sum, 1.0, accuracy: 0.001, file: file, line: line)
    }

    // MARK: - sleepScore

    func testSleepScorePerfectNight() {
        let bedtimes = [date(hour: 23, minute: 0), date(hour: 23, minute: 0), date(hour: 23, minute: 0)]
        let score = HealthScores.sleepScore(hours: 8, quality: 5, bedtimes: bedtimes)
        XCTAssertEqual(score.value, 100)
        assertWeightsSumToOne(score)
    }

    func testSleepScoreMidRangeFewBedtimes() {
        let score = HealthScores.sleepScore(hours: 6, quality: 3, bedtimes: [])
        // duration = 1 - min(2/4,1) = 0.5, quality = (3-1)/4 = 0.5
        // weights rescaled: 0.5/0.8=0.625, 0.3/0.8=0.375 -> 0.5*0.625+0.5*0.375 = 0.5
        XCTAssertEqual(score.value, 50)
        XCTAssertEqual(score.components.count, 2)
        assertWeightsSumToOne(score)
    }

    func testSleepScoreEmptyBedtimesHasTwoComponents() {
        let score = HealthScores.sleepScore(hours: 8, quality: 4, bedtimes: [])
        XCTAssertEqual(score.components.count, 2)
        assertWeightsSumToOne(score)
    }

    func testSleepScoreTwoBedtimesStillRedistributes() {
        let bedtimes = [date(hour: 23, minute: 0), date(hour: 23, minute: 10)]
        let score = HealthScores.sleepScore(hours: 8, quality: 5, bedtimes: bedtimes)
        XCTAssertEqual(score.components.count, 2)
        assertWeightsSumToOne(score)
    }

    func testSleepScoreMidnightStraddleTreatedAsSixtyMinutesApart() {
        let bedtimes = [date(hour: 23, minute: 30), date(hour: 0, minute: 30), date(hour: 23, minute: 30)]
        let straddling = HealthScores.sleepScore(hours: 8, quality: 5, bedtimes: bedtimes)

        let farApartBedtimes = [date(hour: 23, minute: 30), date(hour: 1, minute: 30), date(hour: 23, minute: 30)]
        let farApart = HealthScores.sleepScore(hours: 8, quality: 5, bedtimes: farApartBedtimes)

        XCTAssertEqual(straddling.components.count, 3)
        let straddlingConsistency = straddling.components.first { $0.label == "Consistency" }!.score
        let farApartConsistency = farApart.components.first { $0.label == "Consistency" }!.score
        XCTAssertGreaterThan(straddlingConsistency, farApartConsistency)
        XCTAssertEqual(straddlingConsistency, 0.7642977396044841, accuracy: 0.0001)
        assertWeightsSumToOne(straddling)
    }

    func testSleepScoreValueInRange() {
        let score = HealthScores.sleepScore(hours: 12, quality: 1, bedtimes: [date(hour: 23, minute: 0), date(hour: 4, minute: 0), date(hour: 12, minute: 0)])
        XCTAssertGreaterThanOrEqual(score.value, 0)
        XCTAssertLessThanOrEqual(score.value, 100)
        assertWeightsSumToOne(score)
    }

    // MARK: - readinessScore

    func testReadinessScoreFullMarks() {
        let sleep = HealthScore(value: 100, components: [])
        let score = HealthScores.readinessScore(todayEnergy: 5, lastNightSleep: sleep, last7SleepHours: [8, 8, 8, 8, 8, 8, 8])
        XCTAssertEqual(score.value, 100)
        assertWeightsSumToOne(score)
    }

    func testReadinessScoreEmptyLast7HasTwoComponents() {
        let sleep = HealthScore(value: 80, components: [])
        let score = HealthScores.readinessScore(todayEnergy: 1, lastNightSleep: sleep, last7SleepHours: [])
        XCTAssertEqual(score.components.count, 2)
        XCTAssertEqual(score.value, 40)
        assertWeightsSumToOne(score)
    }

    func testReadinessScoreEnergyOneFloorsComponent() {
        let sleep = HealthScore(value: 100, components: [])
        let score = HealthScores.readinessScore(todayEnergy: 1, lastNightSleep: sleep, last7SleepHours: [8, 8, 8, 8, 8, 8, 8])
        let energyComponent = score.components.first { $0.label == "Energy" }!
        XCTAssertEqual(energyComponent.score, 0.0, accuracy: 0.0001)
        assertWeightsSumToOne(score)
    }

    func testReadinessScoreValueInRange() {
        let sleep = HealthScore(value: 30, components: [])
        let score = HealthScores.readinessScore(todayEnergy: 2, lastNightSleep: sleep, last7SleepHours: [3, 4])
        XCTAssertGreaterThanOrEqual(score.value, 0)
        XCTAssertLessThanOrEqual(score.value, 100)
        assertWeightsSumToOne(score)
    }

    // MARK: - dietScore

    private func makeLimits(fiberMinG: Double = 30, sodiumMaxMg: Double = 2000) -> NutrientLimits {
        let base = NutrientLimits.calculate(sex: .male, age: 30, weightKg: 80, goal: .maintain, targetCalories: 2000)
        return NutrientLimits(
            proteinMinG: 100, proteinMaxG: 200, carbsMinG: 130, carbsMaxG: 400, fatMinG: 50, fatMaxG: 90,
            fiberMinG: fiberMinG, sodiumMaxMg: sodiumMaxMg,
            potassium: base.potassium, calcium: base.calcium, iron: base.iron, zinc: base.zinc,
            magnesium: base.magnesium, phosphorus: base.phosphorus, selenium: base.selenium, copper: base.copper,
            vitaminA: base.vitaminA, vitaminC: base.vitaminC, vitaminD: base.vitaminD, vitaminE: base.vitaminE,
            vitaminK: base.vitaminK, vitaminB1: base.vitaminB1, vitaminB2: base.vitaminB2, vitaminB3: base.vitaminB3,
            vitaminB5: base.vitaminB5, vitaminB6: base.vitaminB6, vitaminB12: base.vitaminB12, folate: base.folate)
    }

    private func makeTargets(calories: Double = 2000, proteinG: Double = 150, limits: NutrientLimits) -> MacroTargets {
        MacroTargets(calories: calories, proteinG: proteinG, carbsG: 200, fatG: 70, limits: limits)
    }

    private func dietScore(calories: Double = 2000, proteinG: Double = 150, fiberG: Double = 30,
                           saturatedFatG: Double = 10, sodiumMg: Double = 1000,
                           microRatios: [Double] = Array(repeating: 1, count: 9),
                           isClosed: Bool = true) -> HealthScore {
        let limits = makeLimits()
        return HealthScores.dietScore(calories: calories, proteinG: proteinG, fiberG: fiberG,
                                      saturatedFatG: saturatedFatG, sodiumMg: sodiumMg,
                                      microRatios: microRatios, targets: makeTargets(limits: limits),
                                      limits: limits, isClosed: isClosed)
    }

    private func component(_ label: String, in score: HealthScore) -> Double {
        score.components.first { $0.label == label }?.score ?? -1
    }

    func testClosedDayOnTargetScoresFull() {
        let score = dietScore()
        XCTAssertEqual(score.value, 100)
        assertWeightsSumToOne(score)
    }

    func testClosedDayCaloriesFallLinearlyInsideTheBand() {
        XCTAssertEqual(component("Calories", in: dietScore(calories: 1800)), 0.6, accuracy: 0.0001)
        XCTAssertEqual(component("Calories", in: dietScore(calories: 2200)), 0.6, accuracy: 0.0001)
    }

    func testClosedDayCaloriesOutsideTheBandScoreZero() {
        XCTAssertEqual(component("Calories", in: dietScore(calories: 1500)), 0, accuracy: 0.0001)
        XCTAssertEqual(component("Calories", in: dietScore(calories: 2600)), 0, accuracy: 0.0001)
    }

    func testDayInProgressWithASmallBalancedMealScoresFull() {
        let score = dietScore(calories: 500, proteinG: 37.5, fiberG: 7.5, saturatedFatG: 5,
                              sodiumMg: 500, microRatios: Array(repeating: 0.25, count: 9), isClosed: false)
        XCTAssertEqual(score.value, 100)
    }

    func testSameSmallMealOnAClosedDayScoresLow() {
        let score = dietScore(calories: 500, proteinG: 37.5, fiberG: 7.5,
                              microRatios: Array(repeating: 0.25, count: 9))
        XCTAssertEqual(component("Calories", in: score), 0, accuracy: 0.0001)
        XCTAssertEqual(component("Protein", in: score), 0.25, accuracy: 0.0001)
        XCTAssertEqual(component("Fiber + micros", in: score), 0.25, accuracy: 0.0001)
    }

    func testDayInProgressOnlyPenalisesCaloriesAboveTarget() {
        XCTAssertEqual(component("Calories", in: dietScore(calories: 900, isClosed: false)), 1, accuracy: 0.0001)
        XCTAssertEqual(component("Calories", in: dietScore(calories: 2250, isClosed: false)), 0.5, accuracy: 0.0001)
    }

    func testDayInProgressFractionIsFlooredAtOneTenth() {
        XCTAssertEqual(component("Protein", in: dietScore(calories: 50, proteinG: 15, isClosed: false)), 1, accuracy: 0.0001)
        XCTAssertEqual(component("Protein", in: dietScore(calories: 50, proteinG: 7.5, isClosed: false)), 0.5, accuracy: 0.0001)
    }

    func testExcessesAreSaturatedFatAndSodiumAndFallUpToOneAndAHalfTimesTheLimit() {
        let saturatedLimit = 2000 * 0.10 / 9
        XCTAssertEqual(component("Excesses", in: dietScore(saturatedFatG: saturatedLimit)), 1, accuracy: 0.0001)
        XCTAssertEqual(component("Excesses", in: dietScore(saturatedFatG: saturatedLimit * 1.25)), 0.75, accuracy: 0.0001)
        XCTAssertEqual(component("Excesses", in: dietScore(saturatedFatG: saturatedLimit * 1.5)), 0.5, accuracy: 0.0001)
        XCTAssertEqual(component("Excesses", in: dietScore(sodiumMg: 3000)), 0.5, accuracy: 0.0001)
        XCTAssertEqual(component("Excesses", in: dietScore(saturatedFatG: 100, sodiumMg: 9000)), 0, accuracy: 0.0001)
    }

    func testMicronutrientsAreTheMeanOfCappedRatios() {
        XCTAssertEqual(component("Fiber + micros", in: dietScore(microRatios: [0.9, 0])), (1 + 0.45) / 2, accuracy: 0.0001)
        XCTAssertEqual(component("Fiber + micros", in: dietScore(microRatios: [2, 0.5])), (1 + 0.75) / 2, accuracy: 0.0001)
    }

    func testNoMicronutrientsTrackedScoresZeroForThatHalf() {
        XCTAssertEqual(component("Fiber + micros", in: dietScore(microRatios: [])), 0.5, accuracy: 0.0001)
    }

    func testDietScoreStaysInRangeWithExtremeIntake() {
        let score = dietScore(calories: 99999, proteinG: 0, fiberG: 0, saturatedFatG: 500,
                              sodiumMg: 90000, microRatios: [0, 0])
        XCTAssertGreaterThanOrEqual(score.value, 0)
        XCTAssertLessThanOrEqual(score.value, 100)
    }

    func testDietScoreWithZeroTargetsDoesNotCrash() {
        let limits = makeLimits(fiberMinG: 0, sodiumMaxMg: 0)
        let targets = makeTargets(calories: 0, proteinG: 0, limits: limits)
        for isClosed in [true, false] {
            let score = HealthScores.dietScore(calories: 0, proteinG: 0, fiberG: 0, saturatedFatG: 0,
                                               sodiumMg: 0, microRatios: [], targets: targets, limits: limits,
                                               isClosed: isClosed)
            XCTAssertGreaterThanOrEqual(score.value, 0)
            XCTAssertLessThanOrEqual(score.value, 100)
        }
    }
}
