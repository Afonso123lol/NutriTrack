import XCTest
@testable import NutriTrack

final class GeminiServiceTests: XCTestCase {

    func testDecodeValidNutritionAnalysis() throws {
        let json = """
        {"dishName":"Grilled chicken with rice","calories":520,"proteinG":42,"carbsG":55,
        "fatG":12,"saturatedFatG":3.5,"omega3G":0.4,"fiberG":2.1,"sugarG":1.5,
        "sodiumMg":680,"potassiumMg":900,"calciumMg":45,"ironMg":3.5,"zincMg":4.2,
        "magnesiumMg":85,"phosphorusMg":320,"seleniumUg":28,"copperUg":120,
        "vitaminCMg":15,"vitaminDUg":0.8,"vitaminEMg":1.2,"vitaminKUg":35,
        "vitaminB1Mg":0.4,"vitaminB2Mg":0.3,"vitaminB3Mg":12,"vitaminB5Mg":1.8,
        "vitaminB6Mg":0.9,"vitaminB12Ug":1.8,"folateUg":42}
        """.data(using: .utf8)!

        let result = try JSONDecoder().decode(NutritionAnalysis.self, from: json)
        XCTAssertEqual(result.dishName, "Grilled chicken with rice")
        XCTAssertEqual(result.calories, 520)
        XCTAssertEqual(result.seleniumUg, 28)
        XCTAssertEqual(result.vitaminB12Ug, 1.8, accuracy: 0.01)
    }

    func testDecodeAllFields() throws {
        let json = """
        {"dishName":"Test","calories":500,"proteinG":30,"carbsG":60,"fatG":15,
        "saturatedFatG":5,"omega3G":1,"fiberG":8,"sugarG":10,"sodiumMg":500,
        "potassiumMg":1000,"calciumMg":200,"ironMg":5,"zincMg":8,"magnesiumMg":150,
        "phosphorusMg":400,"seleniumUg":40,"copperUg":500,"vitaminCMg":60,
        "vitaminDUg":10,"vitaminEMg":8,"vitaminKUg":80,"vitaminB1Mg":1.0,
        "vitaminB2Mg":1.0,"vitaminB3Mg":12,"vitaminB5Mg":4,"vitaminB6Mg":1.2,
        "vitaminB12Ug":2.5,"folateUg":300}
        """.data(using: .utf8)!

        let result = try JSONDecoder().decode(NutritionAnalysis.self, from: json)
        XCTAssertEqual(result.fiberG, 8)
        XCTAssertEqual(result.omega3G, 1)
        XCTAssertEqual(result.copperUg, 500)
        XCTAssertEqual(result.folateUg, 300)
        XCTAssertEqual(result.saturatedFatG, 5)
        XCTAssertEqual(result.sugarG, 10)
    }

    func testDecodeExpandedFieldsWhenPresent() throws {
        let json = """
        {"dishName":"Salmon salad","calories":480,"proteinG":35,"carbsG":12,"fatG":32,
        "saturatedFatG":5,"monounsaturatedFatG":14,"polyunsaturatedFatG":9,"transFatG":0.1,
        "omega3G":2.5,"fiberG":4,"sugarG":3,"sodiumMg":400,"potassiumMg":900,"calciumMg":80,
        "ironMg":2,"zincMg":1.5,"magnesiumMg":60,"phosphorusMg":350,"seleniumUg":45,
        "copperUg":150,"vitaminAUg":120,"vitaminCMg":25,"vitaminDUg":12,"vitaminEMg":4,
        "vitaminKUg":60,"vitaminB1Mg":0.3,"vitaminB2Mg":0.4,"vitaminB3Mg":10,"vitaminB5Mg":1.6,
        "vitaminB6Mg":1.0,"vitaminB12Ug":4.5,"folateUg":70}
        """.data(using: .utf8)!

        let result = try JSONDecoder().decode(NutritionAnalysis.self, from: json)
        XCTAssertEqual(result.monounsaturatedFatG ?? 0, 14, accuracy: 0.01)
        XCTAssertEqual(result.polyunsaturatedFatG ?? 0, 9, accuracy: 0.01)
        XCTAssertEqual(result.transFatG ?? 0, 0.1, accuracy: 0.01)
        XCTAssertEqual(result.vitaminAUg ?? 0, 120, accuracy: 0.01)
        XCTAssertEqual(result.netCarbsG, 8, accuracy: 0.01)
    }

    func testDecodeExpandedFieldsAbsentDefaultsToNil() throws {
        let json = """
        {"dishName":"Plain rice","calories":260,"proteinG":5,"carbsG":56,"fatG":0.5,
        "saturatedFatG":0.1,"omega3G":0,"fiberG":0.6,"sugarG":0.1,"sodiumMg":2,
        "potassiumMg":70,"calciumMg":20,"ironMg":1.2,"zincMg":0.8,"magnesiumMg":24,
        "phosphorusMg":68,"seleniumUg":11,"copperUg":110,"vitaminCMg":0,"vitaminDUg":0,
        "vitaminEMg":0,"vitaminKUg":0,"vitaminB1Mg":0.2,"vitaminB2Mg":0,"vitaminB3Mg":2.3,
        "vitaminB5Mg":0.6,"vitaminB6Mg":0.1,"vitaminB12Ug":0,"folateUg":97}
        """.data(using: .utf8)!

        let result = try JSONDecoder().decode(NutritionAnalysis.self, from: json)
        XCTAssertNil(result.monounsaturatedFatG)
        XCTAssertNil(result.polyunsaturatedFatG)
        XCTAssertNil(result.transFatG)
        XCTAssertNil(result.vitaminAUg)
    }

    func testDecodeMissingFieldThrows() {
        let json = """
        {"dishName":"Incomplete","calories":400}
        """.data(using: .utf8)!

        XCTAssertThrowsError(try JSONDecoder().decode(NutritionAnalysis.self, from: json))
    }
}
