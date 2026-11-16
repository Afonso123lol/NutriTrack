import XCTest
@testable import NutriTrack

final class MicronutrientBoardTests: XCTestCase {

    private let targets = NutritionCalculator.calculate(sex: .male, age: 25, weightKg: 80, heightCm: 180, goal: .maintain)

    private func board(total: NutritionAnalysis = .empty, supplements: NutritionAnalysis = .empty,
                       period: BoardPeriod = .week(completeDays: 7), hasLongSession: Bool = false) -> MicronutrientBoard {
        MicronutrientBoard.make(total: total, supplements: supplements, targets: targets, period: period,
                                hasLongSession: hasLongSession)
    }

    private func reading(_ name: String, in board: MicronutrientBoard) -> NutrientReading {
        (board.key + board.groups.flatMap(\.readings)).first { $0.name == name }!
    }

    private func total(_ change: (inout NutritionAnalysis) -> Void) -> NutritionAnalysis {
        var analysis = NutritionAnalysis.empty
        change(&analysis)
        return analysis
    }

    func testKeyNutrientsComeFirstWithoutOmega3() {
        XCTAssertEqual(board().key.map(\.name),
                       ["Iron", "Vitamin D", "B12", "Magnesium", "Zinc", "Calcium", "Potassium"])
    }

    func testGroupsAreVitaminsMineralsThenFats() {
        XCTAssertEqual(board().groups.map(\.title), ["Vitamins", "Minerals", "Fats, fibre and sugar"])
    }

    func testNoNutrientAppearsTwice() {
        let built = board()
        let names = built.key.map(\.name) + built.groups.flatMap { $0.readings.map(\.name) }
        XCTAssertEqual(names.count, 26)
        XCTAssertEqual(Set(names).count, 26)
    }

    func testEveryNutrientHasAnExplanation() {
        let built = board()
        let names = built.key.map(\.name) + built.groups.flatMap { $0.readings.map(\.name) }
        XCTAssertEqual(names.filter { NutrientInfo.forLabel($0) == nil }, [])
    }

    func testTodayHeadlines() {
        XCTAssertEqual(board(period: .today).headline, "Nothing logged yet today.")
        XCTAssertEqual(board(total: total { $0.calories = 600 }, period: .today).headline,
                       "Today so far, against the daily reference.")
    }

    func testTodayGivesNoVerdict() {
        let built = board(total: total { $0.calories = 600; $0.ironMg = 1; $0.vitaminB6Mg = 100 }, period: .today)
        XCTAssertEqual(reading("Iron", in: built).word, "")
        XCTAssertEqual(reading("B6", in: built).word, "")
        XCTAssertFalse(reading("B6", in: built).geometry.isOver)
        XCTAssertEqual(built.groups.map(\.summary), ["", "", ""])
    }

    func testWeekHeadlineCountsCompleteDaysAndKeyNutrientsOnTarget() {
        let eaten = total {
            $0.calories = 600
            $0.ironMg = targets.limits.iron.reference + 1
            $0.zincMg = targets.limits.zinc.reference + 1
        }
        XCTAssertEqual(board(total: eaten, period: .week(completeDays: 5)).headline,
                       "5 of 7 complete days. 2 of 7 key nutrients on target.")
    }

    func testWeekWithFewCompleteDaysGivesNoVerdict() {
        let built = board(total: total { $0.ironMg = 1 }, period: .week(completeDays: 3))
        XCTAssertEqual(built.headline, "3 of 7 complete days. Too few to judge the week.")
        XCTAssertEqual(reading("Iron", in: built).word, "")
        XCTAssertEqual(board(period: .week(completeDays: 0)).headline, "No complete days in the last 7.")
        XCTAssertEqual(reading("Iron", in: board(total: total { $0.ironMg = 1 }, period: .week(completeDays: 4))).word, "Low")
    }

    func testNutrientsWithoutAnUpperLevelAreNeverOver() {
        let built = board(total: total { $0.potassiumMg = 20000; $0.vitaminB12Ug = 5000; $0.vitaminKUg = 5000 })
        XCTAssertEqual(reading("Potassium", in: built).word, "On target")
        XCTAssertEqual(reading("B12", in: built).word, "On target")
        XCTAssertEqual(reading("Vitamin K", in: built).word, "On target")
        XCTAssertEqual(reading("B12", in: built).amount, "5000 / 4+ µg")
    }

    func testEuropeanUpperLevels() {
        let built = board(total: total {
            $0.vitaminB6Mg = 13; $0.zincMg = 26; $0.seleniumUg = 256; $0.vitaminEMg = 301
        })
        for name in ["B6", "Zinc", "Selenium", "Vitamin E"] {
            XCTAssertEqual(reading(name, in: built).word, "Over limit", name)
        }
    }

    func testIronAboveTheSafeLevelSaysSo() {
        XCTAssertEqual(reading("Iron", in: board(total: total { $0.ironMg = 41 })).word, "Above safe level")
    }

    func testMagnesiumAndVitaminAFromFoodAreNeverOver() {
        let built = board(total: total { $0.magnesiumMg = 900; $0.vitaminAUg = 5000 })
        XCTAssertEqual(reading("Magnesium", in: built).word, "On target")
        XCTAssertEqual(reading("Vitamin A", in: built).word, "On target")
    }

    func testMagnesiumAndVitaminAFromSupplementsCanBeOver() {
        let supplements = total { $0.magnesiumMg = 251; $0.vitaminAUg = 3001 }
        let built = board(total: total { $0.magnesiumMg = 551; $0.vitaminAUg = 3500 }, supplements: supplements)
        XCTAssertEqual(reading("Magnesium", in: built).word, "Over limit")
        XCTAssertEqual(reading("Magnesium", in: built).supplementNote, "From supplements: 251 of 250 mg limit")
        XCTAssertEqual(reading("Vitamin A", in: built).word, "Over limit")
    }

    func testSupplementsAreShownApartFromFood() {
        let built = board(total: total { $0.ironMg = 20 }, supplements: total { $0.ironMg = 14 })
        XCTAssertEqual(reading("Iron", in: built).supplementNote, "From supplements: 14 mg")
    }

    func testSugarAndOmega3ShowTheAmountWithoutAVerdict() {
        let built = board(total: total { $0.sugarG = 80; $0.omega3G = 0.2 })
        XCTAssertEqual(reading("Sugar", in: built).rule, .plain)
        XCTAssertEqual(reading("Sugar", in: built).word, "")
        XCTAssertEqual(reading("Sugar", in: built).amount, "80 g")
        XCTAssertEqual(reading("Omega-3", in: built).rule, .plain)
        XCTAssertEqual(reading("Omega-3", in: built).word, "")
    }

    func testTransFatLimitIsOnePercentOfEnergy() {
        XCTAssertEqual(reading("Trans fat", in: board()).ceiling, targets.calories * 0.01 / 9, accuracy: 0.001)
    }

    func testFibreHasATargetAndNoCeiling() {
        let built = board(total: total { $0.fiberG = 200 })
        XCTAssertEqual(reading("Fiber", in: built).rule, .floor)
        XCTAssertEqual(reading("Fiber", in: built).word, "On target")
    }

    func testSodiumOnALongSessionDayIsNotALimit() {
        let salty = total { $0.calories = 600; $0.sodiumMg = 4000 }
        let longDay = reading("Sodium", in: board(total: salty, period: .today, hasLongSession: true))
        XCTAssertEqual(longDay.rule, .plain)
        XCTAssertEqual(longDay.note, "Long session today: sodium needs are higher.")
        let usual = reading("Sodium", in: board(total: salty, period: .today, hasLongSession: false))
        XCTAssertEqual(usual.rule, .limit)
        XCTAssertNil(usual.note)
        XCTAssertEqual(reading("Sodium", in: board(total: salty, hasLongSession: true)).word, "Over limit")
    }

    func testEachReferenceCarriesItsSource() {
        let built = board()
        XCTAssertEqual(reading("Iron", in: built).basis, "Reference: EFSA. Safe level: EFSA.")
        XCTAssertEqual(reading("Sodium", in: built).basis, "Limit: EFSA and WHO, 2 g a day.")
        XCTAssertNotNil(reading("Sugar", in: built).basis)
    }

    func testSummaryCountsLowAndOver() {
        func row(_ rule: NutrientReading.Rule, _ value: Double, _ floor: Double, _ ceiling: Double) -> NutrientReading {
            NutrientReading(name: "X", value: value, unit: "mg", floor: floor, ceiling: ceiling, rule: rule)
        }
        let readings = [row(.range, 1, 8, 45), row(.range, 2, 8, 45), row(.range, 50, 8, 45), row(.limit, 60, 0, 72)]
        XCTAssertEqual(MicronutrientBoard.summary(of: readings), "2 low · 1 over limit")
        XCTAssertEqual(MicronutrientBoard.summary(of: [row(.range, 12, 8, 45)]), "On target")
    }

    func testTheWeekSodiumLeavesOutLongSessionDaysWhenGiven() {
        let salty = total { $0.calories = 2000; $0.sodiumMg = 3000 }
        let built = MicronutrientBoard.make(total: salty, supplements: .empty, targets: targets,
                                            period: .week(completeDays: 5), hasLongSession: false,
                                            weekSodiumWithoutLongDays: (mg: 1800, leftOut: 2))
        let sodium = reading("Sodium", in: built)
        XCTAssertEqual(sodium.value, 1800)
        XCTAssertNotEqual(sodium.word, "Over limit")
        XCTAssertEqual(sodium.note, "Leaves out 2 days with a session over 2 h.")
    }
}
