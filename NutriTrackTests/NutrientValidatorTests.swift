import XCTest
@testable import NutriTrack

final class NutrientValidatorTests: XCTestCase {

    private func makeAnalysis(
        calories: Double = 450,
        proteinG: Double = 40,
        carbsG: Double = 50,
        fatG: Double = 10,
        saturatedFatG: Double = 3,
        monounsaturatedFatG: Double? = nil,
        polyunsaturatedFatG: Double? = nil,
        transFatG: Double? = nil,
        fiberG: Double = 5,
        sugarG: Double = 8,
        sodiumMg: Double = 500
    ) -> NutritionAnalysis {
        NutritionAnalysis(
            dishName: "Test meal", comment: nil, calories: calories,
            proteinG: proteinG, carbsG: carbsG, fatG: fatG,
            saturatedFatG: saturatedFatG,
            monounsaturatedFatG: monounsaturatedFatG,
            polyunsaturatedFatG: polyunsaturatedFatG,
            transFatG: transFatG,
            omega3G: 0.5, fiberG: fiberG, sugarG: sugarG,
            sodiumMg: sodiumMg, potassiumMg: 800, calciumMg: 100,
            ironMg: 3, zincMg: 4, magnesiumMg: 80, phosphorusMg: 300,
            seleniumUg: 25, copperUg: 150, vitaminAUg: 100,
            vitaminCMg: 20, vitaminDUg: 1, vitaminEMg: 2, vitaminKUg: 30,
            vitaminB1Mg: 0.4, vitaminB2Mg: 0.3, vitaminB3Mg: 8,
            vitaminB5Mg: 1.5, vitaminB6Mg: 0.8, vitaminB12Ug: 1.5, folateUg: 60
        )
    }

    func testCaloriesRecalculatedWhenViolating449() {
        let input = makeAnalysis(calories: 800, proteinG: 40, carbsG: 50, fatG: 10)
        let result = NutrientValidator.validate(input)
        // 40*4 + 50*4 + 10*9 = 450
        XCTAssertEqual(result.calories, 450, accuracy: 0.5)
        XCTAssertTrue(result.validationFlags?.contains { $0.contains("4-4-9") } ?? false)
    }

    func testAbsurdCaloriesWithoutMacrosAreCapped() {
        let input = makeAnalysis(calories: 1e19, proteinG: 0, carbsG: 0, fatG: 0, saturatedFatG: 0, fiberG: 0, sugarG: 0)
        let result = NutrientValidator.validate(input)
        XCTAssertEqual(result.calories, NutrientValidator.maxCaloriesPerMeal)
        XCTAssertTrue(result.validationFlags?.contains { $0.contains("Calories capped") } ?? false)
    }

    func testNegativeValuesBecomeZero() {
        let input = makeAnalysis(calories: -10, proteinG: -5, carbsG: 50, fatG: 10, saturatedFatG: -1,
                                 monounsaturatedFatG: -3, fiberG: 5, sugarG: -2, sodiumMg: -100)
        let result = NutrientValidator.validate(input)
        XCTAssertEqual(result.proteinG, 0)
        XCTAssertEqual(result.saturatedFatG, 0)
        XCTAssertEqual(result.monounsaturatedFatG, 0)
        XCTAssertEqual(result.sugarG, 0)
        XCTAssertEqual(result.sodiumMg, 0)
        XCTAssertGreaterThanOrEqual(result.calories, 0)
    }

    func testConsistentCaloriesUntouched() {
        let input = makeAnalysis(calories: 455, proteinG: 40, carbsG: 50, fatG: 10)
        let result = NutrientValidator.validate(input)
        XCTAssertEqual(result.calories, 455)
        XCTAssertNil(result.validationFlags)
    }

    func testSugarCappedAtCarbs() {
        let input = makeAnalysis(calories: 450, carbsG: 50, sugarG: 70)
        let result = NutrientValidator.validate(input)
        XCTAssertEqual(result.sugarG, 50)
    }

    func testSaturatedFatCappedAtFat() {
        let input = makeAnalysis(calories: 450, fatG: 10, saturatedFatG: 15)
        let result = NutrientValidator.validate(input)
        XCTAssertEqual(result.saturatedFatG, 10)
    }

    func testFatSplitScaledToTotalFat() {
        let input = makeAnalysis(calories: 450, fatG: 10, saturatedFatG: 6,
                                 monounsaturatedFatG: 6, polyunsaturatedFatG: 6)
        let result = NutrientValidator.validate(input)
        let split = result.saturatedFatG + (result.monounsaturatedFatG ?? 0) + (result.polyunsaturatedFatG ?? 0)
        XCTAssertEqual(split, 10, accuracy: 0.01)
        XCTAssertTrue(result.validationFlags?.contains { $0.contains("Fat breakdown") } ?? false)
    }

    func testSodiumOutlierClamped() {
        let input = makeAnalysis(calories: 450, sodiumMg: 20000)
        let result = NutrientValidator.validate(input)
        XCTAssertEqual(result.sodiumMg, 8000)
        XCTAssertTrue(result.validationFlags?.contains { $0.contains("Sodium") } ?? false)
    }

    func testMissingMicronutrientsFlagged() {
        var input = makeAnalysis(calories: 450)
        input.sodiumMg = 0; input.potassiumMg = 0; input.calciumMg = 0
        input.ironMg = 0; input.zincMg = 0; input.magnesiumMg = 0
        input.phosphorusMg = 0; input.seleniumUg = 0
        input.vitaminCMg = 0; input.vitaminB12Ug = 0
        let result = NutrientValidator.validate(input)
        XCTAssertTrue(result.validationFlags?.contains { $0.contains("Micronutrient data missing") } ?? false)
    }

    func testNetCarbsComputed() {
        let input = makeAnalysis(carbsG: 50, fiberG: 8)
        XCTAssertEqual(input.netCarbsG, 42, accuracy: 0.01)
    }

    func testAlcoholCountsSevenCaloriesPerGram() {
        var analysis = makeAnalysis(calories: 158, proteinG: 5, carbsG: 10, fatG: 0)
        analysis.alcoholG = 14
        XCTAssertEqual(NutrientValidator.validate(analysis).calories, 158)

        analysis.calories = 60
        let fixed = NutrientValidator.validate(analysis)
        XCTAssertEqual(fixed.calories, 158)
        XCTAssertTrue(fixed.validationFlags?.contains { $0.contains("4-4-9") } ?? false)
    }

    func testAlcoholIsClampedAndCapped() {
        var analysis = makeAnalysis(calories: 60, proteinG: 5, carbsG: 10, fatG: 0)
        analysis.alcoholG = -3
        XCTAssertEqual(NutrientValidator.validate(analysis).alcoholG, 0)

        analysis.alcoholG = 400
        let capped = NutrientValidator.validate(analysis)
        XCTAssertEqual(capped.alcoholG, 150)
        XCTAssertTrue(capped.validationFlags?.contains { $0.contains("Alcohol") } ?? false)
    }

    func testKeepCaloriesSkipsTheMacroRecalculation() {
        let analysis = makeAnalysis(calories: 500, proteinG: 10, carbsG: 10, fatG: 2)
        XCTAssertEqual(NutrientValidator.validate(analysis, keepCalories: true).calories, 500)
        XCTAssertEqual(NutrientValidator.validate(analysis).calories, 98)
    }

    func testKeepCaloriesStillCapsAbsurdValues() {
        let analysis = makeAnalysis(calories: 90000, proteinG: 10, carbsG: 10, fatG: 2)
        XCTAssertEqual(NutrientValidator.validate(analysis, keepCalories: true).calories,
                       NutrientValidator.maxCaloriesPerMeal)
    }

    func testAlcoholAddsANoticeToCheckTheValue() {
        var analysis = makeAnalysis(calories: 116, proteinG: 5, carbsG: 10, fatG: 0)
        analysis.alcoholG = 8
        XCTAssertEqual(NutrientValidator.validate(analysis).validationFlags?.contains(NutrientValidator.alcoholNotice), true)
        analysis.alcoholG = 0
        XCTAssertNotEqual(NutrientValidator.validate(analysis).validationFlags?.contains(NutrientValidator.alcoholNotice), true)
    }
}
