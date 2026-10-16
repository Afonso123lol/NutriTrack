import XCTest
@testable import NutriTrack

final class MealEditorTests: XCTestCase {

    private func original() throws -> NutritionAnalysis {
        let json = #"{"dishName":"Grilled chicken with rice","calories":520,"proteinG":42,"carbsG":55,"fatG":12,"saturatedFatG":3.5,"omega3G":0.4,"fiberG":2.1,"sugarG":1.5,"sodiumMg":680,"potassiumMg":900,"calciumMg":45,"ironMg":3.5,"zincMg":4.2,"magnesiumMg":85,"phosphorusMg":320,"seleniumUg":28,"copperUg":120,"vitaminCMg":15,"vitaminDUg":0.8,"vitaminEMg":1.2,"vitaminKUg":35,"vitaminB1Mg":0.4,"vitaminB2Mg":0.3,"vitaminB3Mg":12,"vitaminB5Mg":1.8,"vitaminB6Mg":0.9,"vitaminB12Ug":1.8,"folateUg":42}"#
        return try JSONDecoder().decode(NutritionAnalysis.self, from: Data(json.utf8))
    }

    private func edit(_ base: NutritionAnalysis, name: String? = nil, calories: Double? = nil, proteinG: Double? = nil,
                      carbsG: Double? = nil, fatG: Double? = nil, alcoholG: Double? = nil) -> NutritionAnalysis {
        MealEditor.edited(base, dishName: name ?? base.dishName, calories: calories ?? base.calories,
                          proteinG: proteinG ?? base.proteinG, carbsG: carbsG ?? base.carbsG,
                          fatG: fatG ?? base.fatG, alcoholG: alcoholG ?? (base.alcoholG ?? 0))
    }

    func testNothingChangedKeepsTheNumbers() throws {
        let result = edit(try original())
        XCTAssertEqual(result.calories, 520)
        XCTAssertEqual(result.proteinG, 42)
        XCTAssertEqual(result.sodiumMg, 680)
    }

    func testChangingAMacroRecalculatesCalories() throws {
        XCTAssertEqual(edit(try original(), proteinG: 50).calories, 528)
    }

    func testAlcoholAddsSevenCaloriesPerGram() throws {
        let result = edit(try original(), alcoholG: 10)
        XCTAssertEqual(result.alcoholG, 10)
        XCTAssertEqual(result.calories, 566)
    }

    func testTypedCaloriesAreKept() throws {
        XCTAssertEqual(edit(try original(), calories: 700).calories, 700)
        XCTAssertEqual(edit(try original(), calories: 700, proteinG: 10).calories, 700)
    }

    func testTinyRoundingDifferencesAreNotEdits() throws {
        var base = try original()
        base.calories = 700
        let result = edit(base, proteinG: 42.03)
        XCTAssertEqual(result.calories, 700)
    }

    func testNegativeAndAbsurdValuesAreBounded() throws {
        let result = edit(try original(), calories: 99999, proteinG: -5, carbsG: 9000)
        XCTAssertEqual(result.proteinG, 0)
        XCTAssertEqual(result.carbsG, 600)
        XCTAssertEqual(result.calories, NutrientValidator.maxCaloriesPerMeal)
    }

    func testLoweringFatKeepsTheBreakdownConsistent() throws {
        XCTAssertEqual(edit(try original(), fatG: 2).saturatedFatG, 2)
    }

    func testNameIsTrimmedAndAnEmptyNameKeepsTheOriginal() throws {
        XCTAssertEqual(edit(try original(), name: "  Chicken bowl \n").dishName, "Chicken bowl")
        XCTAssertEqual(edit(try original(), name: "   ").dishName, "Grilled chicken with rice")
    }

    func testScalingAPortionScalesEverything() throws {
        let half = MealEditor.scaled(try original(), by: 0.5)
        XCTAssertEqual(half.calories, 260)
        XCTAssertEqual(half.proteinG, 21)
        XCTAssertEqual(half.sodiumMg, 340)
        XCTAssertEqual(MealEditor.scaled(try original(), by: 10).proteinG, 300)
    }

    func testMultiplierAcceptsCommaAndRejectsOutOfRange() {
        XCTAssertEqual(MealEditor.multiplier(from: "1,5"), 1.5)
        XCTAssertEqual(MealEditor.multiplier(from: " 0.1 "), 0.1)
        XCTAssertEqual(MealEditor.multiplier(from: "10"), 10)
        XCTAssertNil(MealEditor.multiplier(from: "0"))
        XCTAssertNil(MealEditor.multiplier(from: "11"))
        XCTAssertNil(MealEditor.multiplier(from: "abc"))
        XCTAssertNil(MealEditor.multiplier(from: ""))
    }
}
