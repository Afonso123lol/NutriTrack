import XCTest
import CoreData
@testable import NutriTrack

final class OpenFoodFactsTests: XCTestCase {

    private let mousse = #"""
{"code":"5601312513469","product":{"brands":"Continente","code":"5601312513469","nutriments":{"added-sugars":0,"added-sugars_100g":0,"added-sugars_modifier":"~","added-sugars_serving":0,"added-sugars_unit":"g","added-sugars_value":0,"carbohydrates":6.33333333333333,"carbohydrates_100g":6.33333333333333,"carbohydrates_serving":9.5,"carbohydrates_unit":"g","carbohydrates_value":6.33333333333333,"energy":361.266666666667,"energy-kcal":87.3333333333333,"energy-kcal_100g":87.3333333333333,"energy-kcal_serving":131,"energy-kcal_unit":"kcal","energy-kcal_value":87.3333333333333,"energy-kj":361.266666666667,"energy-kj_100g":361.266666666667,"energy-kj_modifier":"~","energy-kj_serving":542,"energy-kj_unit":"kJ","energy-kj_value":361.266666666667,"energy_100g":361.266666666667,"energy_modifier":"~","energy_serving":542,"energy_unit":"kJ","energy_value":361.266666666667,"fat":2,"fat_100g":2,"fat_serving":3,"fat_unit":"g","fat_value":2,"fiber":1.2,"fiber_100g":1.2,"fiber_serving":1.8,"fiber_unit":"g","fiber_value":1.2,"fruits-vegetables-legumes-estimate-from-ingredients_100g":0,"fruits-vegetables-nuts-estimate-from-ingredients_100g":0,"nova-group":4,"nova-group_100g":4,"nova-group_serving":4,"nova-group_unit":"","nova-group_value":4,"proteins":10,"proteins_100g":10,"proteins_serving":15,"proteins_unit":"g","proteins_value":10,"salt":0.288333333333333,"salt_100g":0.288333333333333,"salt_serving":0.432,"salt_unit":"g","salt_value":0.288333333333333,"saturated-fat":1.33333333333333,"saturated-fat_100g":1.33333333333333,"saturated-fat_serving":2,"saturated-fat_unit":"g","saturated-fat_value":1.33333333333333,"sodium":0.115333333333333,"sodium_100g":0.115333333333333,"sodium_serving":0.173,"sodium_unit":"g","sodium_value":0.115333333333333,"sugars":3.2,"sugars_100g":3.2,"sugars_serving":4.8,"sugars_unit":"g","sugars_value":3.2},"nutrition_data":"on","nutrition_data_per":"100g","nutrition_data_prepared_per":"100g","product_name":"+ Proteína Mouse sabor Chocolate","product_name_pt":"+ Proteína Mouse sabor Chocolate","product_quantity":150,"product_quantity_unit":"g","quantity":"150 g","serving_quantity":150,"serving_size":"150 g"},"status":1,"status_verbose":"product found"}
"""#

    private let yogurt = #"""
{"code":"3023290086247","product":{"brands":"Lindahls","code":"3023290086247","nutriments":{"carbohydrates":4.1,"carbohydrates_100g":4.1,"carbohydrates_unit":"g","carbohydrates_value":4.1,"energy":247.1,"energy-kcal":59,"energy-kcal_100g":59,"energy-kcal_unit":"kcal","energy-kcal_value":59,"energy-kj":247.1,"energy-kj_100g":247.1,"energy-kj_modifier":"~","energy-kj_unit":"kJ","energy-kj_value":247.1,"energy_100g":247.1,"energy_modifier":"~","energy_unit":"kJ","energy_value":247.1,"fat":0.2,"fat_100g":0.2,"fat_unit":"g","fat_value":0.2,"fiber":0,"fiber_100g":0,"fiber_unit":"g","fiber_value":0,"proteins":10,"proteins_100g":10,"proteins_unit":"g","proteins_value":10,"salt":0.1175,"salt_100g":0.1175,"salt_modifier":"~","salt_unit":"g","salt_value":0.1175,"saturated-fat":0.1,"saturated-fat_100g":0.1,"saturated-fat_unit":"g","saturated-fat_value":0.1,"sodium":0.047,"sodium_100g":0.047,"sodium_unit":"g","sodium_value":0.047,"sugars":3.7,"sugars_100g":3.7,"sugars_unit":"g","sugars_value":3.7},"nutrition_data":"on","nutrition_data_prepared_per":"100g","product_name":"Protein Yogurt Strawberry Lime"},"status":1,"status_verbose":"product found"}
"""#

    func testValidBarcodesPassTheCheckDigit() {
        XCTAssertTrue(OpenFoodFacts.isValidBarcode("5601312513469"))
        XCTAssertTrue(OpenFoodFacts.isValidBarcode("3023290086247"))
        XCTAssertTrue(OpenFoodFacts.isValidBarcode("96385074"))
        XCTAssertFalse(OpenFoodFacts.isValidBarcode("5601312513468"))
        XCTAssertFalse(OpenFoodFacts.isValidBarcode("56013125134"))
        XCTAssertFalse(OpenFoodFacts.isValidBarcode("56013125134a9"))
        XCTAssertNil(OpenFoodFacts.productURL(ean: "../../x"))
    }

    func testProductURLAsksOnlyForTheNeededFields() throws {
        let url = try XCTUnwrap(OpenFoodFacts.productURL(ean: "5601312513469"))
        XCTAssertEqual(url.host(), "world.openfoodfacts.org")
        XCTAssertTrue(url.path().hasSuffix("/api/v2/product/5601312513469.json"))
        XCTAssertTrue(url.query()?.contains("fields=") == true)
    }

    func testParsesARealContinenteProduct() throws {
        let info = try XCTUnwrap(OpenFoodFacts.parse(Data(mousse.utf8), ean: "5601312513469"))
        XCTAssertEqual(info.name, "+ Proteína Mouse sabor Chocolate")
        XCTAssertEqual(info.brand, "Continente")
        XCTAssertEqual(info.caloriesPer100, 87.33, accuracy: 0.01)
        XCTAssertEqual(info.proteinPer100, 10)
        XCTAssertEqual(info.sodiumMgPer100, 115.33, accuracy: 0.01)
        XCTAssertEqual(info.packageG, 150)
        XCTAssertEqual(info.servingG, 150)
    }

    func testPortionScalesTheLabel() throws {
        let info = try XCTUnwrap(OpenFoodFacts.parse(Data(mousse.utf8), ean: "5601312513469"))
        let pack = info.analysis(grams: 150)
        XCTAssertEqual(pack.calories, 131, accuracy: 0.01)
        XCTAssertEqual(pack.proteinG, 15, accuracy: 0.001)
        XCTAssertEqual(pack.dishName, "+ Proteína Mouse sabor Chocolate · Continente")
        XCTAssertEqual(info.analysis(grams: 0).calories, 0)
    }

    func testProductWithoutPackageSizeOffersOnlyGrams() throws {
        let info = try XCTUnwrap(OpenFoodFacts.parse(Data(yogurt.utf8), ean: "3023290086247"))
        XCTAssertNil(info.packageG)
        XCTAssertEqual(ProductPortion.choices(for: info, lastGrams: nil).map(\.label), ["100 g"])
        XCTAssertEqual(ProductPortion.choices(for: info, lastGrams: 170).map(\.label), ["Last time (170 g)", "100 g"])
    }

    func testPackAndServingAreNotRepeated() throws {
        let info = try XCTUnwrap(OpenFoodFacts.parse(Data(mousse.utf8), ean: "5601312513469"))
        XCTAssertEqual(ProductPortion.choices(for: info, lastGrams: 150).map(\.label), ["1 pack (150 g)", "100 g"])
    }

    func testNotFoundAndMissingMacrosReturnNil() throws {
        XCTAssertNil(try OpenFoodFacts.parse(Data(#"{"code":"5601312187455","status":0,"status_verbose":"product not found"}"#.utf8),
                                             ean: "5601312187455"))
        let noFat = #"{"status":1,"product":{"product_name":"X","nutriments":{"energy-kcal_100g":100,"proteins_100g":1,"carbohydrates_100g":2}}}"#
        XCTAssertNil(try OpenFoodFacts.parse(Data(noFat.utf8), ean: "5601312513469"))
        XCTAssertThrowsError(try OpenFoodFacts.parse(Data("<html>".utf8), ean: "5601312513469"))
    }

    func testFallsBackToKilojoulesAndSalt() throws {
        let json = #"{"status":1,"product":{"product_name":"Bread","brands":"Padaria, Outra","nutriments":{"energy-kj_100g":1046,"proteins_100g":"8,5","carbohydrates_100g":50,"fat_100g":3,"salt_100g":1.2}}}"#
        let info = try XCTUnwrap(OpenFoodFacts.parse(Data(json.utf8), ean: "5601312513469"))
        XCTAssertEqual(info.caloriesPer100, 250, accuracy: 0.1)
        XCTAssertEqual(info.proteinPer100, 8.5)
        XCTAssertEqual(info.sodiumMgPer100, 480, accuracy: 0.01)
        XCTAssertEqual(info.brand, "Padaria")
    }

    func testPackageSizeFallsBackToTheQuantityText() throws {
        XCTAssertEqual(OpenFoodFacts.packageGrams("150 g"), 150)
        XCTAssertEqual(OpenFoodFacts.packageGrams("1,5 kg"), 1500)
        XCTAssertEqual(OpenFoodFacts.packageGrams("33cl"), 330)
        XCTAssertEqual(OpenFoodFacts.packageGrams("500 ml"), 500)
        XCTAssertNil(OpenFoodFacts.packageGrams("6 x 125 g"))
        XCTAssertNil(OpenFoodFacts.packageGrams("2 unidades"))
        let json = #"{"status":1,"product":{"product_name":"Mousse","quantity":"150 g","serving_quantity":150,"nutriments":{"energy-kcal_100g":87,"proteins_100g":10,"carbohydrates_100g":6,"fat_100g":2}}}"#
        let info = try XCTUnwrap(OpenFoodFacts.parse(Data(json.utf8), ean: "5601312513469"))
        XCTAssertEqual(info.packageG, 150)
        XCTAssertEqual(ProductPortion.choices(for: info, lastGrams: nil).map(\.label), ["1 pack (150 g)", "100 g"])
    }

    @MainActor
    func testStoringAndLoggingAProduct() throws {
        let ctx = Persistence(inMemory: true).container.viewContext
        let info = try XCTUnwrap(OpenFoodFacts.parse(Data(mousse.utf8), ean: "5601312513469"))
        let product = Product.store(info, source: "openfoodfacts", in: ctx)
        XCTAssertEqual(Product.store(info, source: "openfoodfacts", in: ctx), product)
        XCTAssertEqual(try ctx.count(for: Product.fetchRequest()), 1)
        XCTAssertEqual(Product.find(ean: "5601312513469", in: ctx)?.info, info)

        let portion = try XCTUnwrap(ProductPortion.choices(for: info, lastGrams: nil).first)
        let entry = FoodEntry.create(from: product, portion: portion, in: ctx)
        XCTAssertEqual(entry.calories, 131, accuracy: 0.01)
        XCTAssertEqual(entry.source, "label")
        XCTAssertEqual(entry.productEAN, "5601312513469")
        XCTAssertEqual(entry.grams, 150)
        XCTAssertEqual(entry.portionLabel, "1 pack (150 g)")
        XCTAssertEqual(product.useCount, 1)
        XCTAssertEqual(product.lastGrams, 150)
        XCTAssertTrue(EvaluationService.hasFood(on: Date(), in: ctx))
    }

    func testProductsAreNotSynced() {
        XCTAssertFalse(SyncEntities.all.contains("Product"))
    }
}
