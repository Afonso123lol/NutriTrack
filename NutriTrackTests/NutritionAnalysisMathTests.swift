import XCTest
@testable import NutriTrack

final class NutritionAnalysisMathTests: XCTestCase {

    private func sample() throws -> NutritionAnalysis {
        let json = #"{"dishName":"Grilled chicken with rice","calories":520,"proteinG":42,"carbsG":55,"fatG":12,"saturatedFatG":3.5,"transFatG":0.2,"omega3G":0.4,"fiberG":2.1,"sugarG":1.5,"sodiumMg":680,"potassiumMg":900,"calciumMg":45,"ironMg":3.5,"zincMg":4.2,"magnesiumMg":85,"phosphorusMg":320,"seleniumUg":28,"copperUg":120,"vitaminCMg":15,"vitaminDUg":0.8,"vitaminEMg":1.2,"vitaminKUg":35,"vitaminB1Mg":0.4,"vitaminB2Mg":0.3,"vitaminB3Mg":12,"vitaminB5Mg":1.8,"vitaminB6Mg":0.9,"vitaminB12Ug":1.8,"folateUg":42}"#
        return try JSONDecoder().decode(NutritionAnalysis.self, from: Data(json.utf8))
    }

    func testOldRecordsWithoutAlcoholStillDecode() throws {
        XCTAssertNil(try sample().alcoholG)
    }

    func testAlcoholDecodesWhenPresent() throws {
        let json = #"{"dishName":"Beer","calories":150,"proteinG":1,"carbsG":12,"fatG":0,"saturatedFatG":0,"omega3G":0,"fiberG":0,"sugarG":0,"sodiumMg":10,"potassiumMg":90,"calciumMg":10,"ironMg":0,"zincMg":0,"magnesiumMg":20,"phosphorusMg":40,"seleniumUg":1,"copperUg":10,"vitaminCMg":0,"vitaminDUg":0,"vitaminEMg":0,"vitaminKUg":0,"vitaminB1Mg":0,"vitaminB2Mg":0.1,"vitaminB3Mg":1.5,"vitaminB5Mg":0.1,"vitaminB6Mg":0.1,"vitaminB12Ug":0.1,"folateUg":20,"alcoholG":14}"#
        XCTAssertEqual(try JSONDecoder().decode(NutritionAnalysis.self, from: Data(json.utf8)).alcoholG, 14)
    }

    func testScalingMultipliesEveryNutrientAndKeepsTheName() throws {
        var analysis = try sample()
        analysis.alcoholG = 10
        let doubled = analysis.scaled(by: 2)
        XCTAssertEqual(doubled.dishName, "Grilled chicken with rice")
        XCTAssertEqual(doubled.calories, 1040)
        XCTAssertEqual(doubled.proteinG, 84)
        XCTAssertEqual(doubled.folateUg, 84)
        XCTAssertEqual(doubled.transFatG ?? 0, 0.4, accuracy: 0.0001)
        XCTAssertEqual(doubled.alcoholG, 20)
        XCTAssertNil(doubled.vitaminAUg)
    }

    func testSumAddsRequiredAndOptionalFields() throws {
        var first = try sample()
        first.alcoholG = 5
        let total = NutritionAnalysis.sum([first, try sample()])
        XCTAssertEqual(total.calories, 1040)
        XCTAssertEqual(total.sodiumMg, 1360)
        XCTAssertEqual(total.transFatG ?? 0, 0.4, accuracy: 0.0001)
        XCTAssertEqual(total.alcoholG, 5)
    }

    func testSumOfNothingIsZero() {
        let total = NutritionAnalysis.sum([])
        XCTAssertEqual(total.calories, 0)
        XCTAssertEqual(total.alcoholG, 0)
    }
}
