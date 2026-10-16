import XCTest
@testable import NutriTrack

final class NutrientInfoTests: XCTestCase {

    private let mealLabels = [
        "Calories", "Protein", "Carbohydrates", "Net carbs", "Fiber", "Sugar", "Fat", "Saturated fat",
        "Monounsaturated fat", "Polyunsaturated fat", "Trans fat", "Omega-3", "Alcohol",
        "Sodium", "Potassium", "Calcium", "Iron", "Zinc", "Magnesium", "Phosphorus", "Selenium", "Copper",
        "Vitamin A", "Vitamin C", "Vitamin D", "Vitamin E", "Vitamin K", "B1 (Thiamine)", "B2 (Riboflavin)",
        "B3 (Niacin)", "B5 (Pantothenic)", "B6", "B12", "Folate (B9)"
    ]

    private let dayLabels = ["B1 Thiamine", "B2 Riboflavin", "B3 Niacin", "B5 Pantothenic"]

    func testEveryNutrientShownInTheAppHasAnExplanation() {
        for label in mealLabels + dayLabels {
            XCTAssertNotNil(NutrientInfo.forLabel(label), label)
        }
        XCTAssertEqual(NutrientInfo.all.count, mealLabels.count)
    }

    func testLabelsWithAndWithoutParenthesesGiveTheSameExplanation() {
        XCTAssertEqual(NutrientInfo.forLabel("B1 (Thiamine)"), NutrientInfo.forLabel("B1 Thiamine"))
        XCTAssertEqual(NutrientInfo.forLabel("iron"), NutrientInfo.forLabel("Iron"))
        XCTAssertNil(NutrientInfo.forLabel("Kryptonite"))
    }

    func testExplanationsAreShortAndComplete() {
        for info in NutrientInfo.all.values {
            XCTAssertFalse(info.name.isEmpty)
            XCTAssertGreaterThan(info.why.count, 40, info.name)
            XCTAssertLessThan(info.why.count, 260, info.name)
            XCTAssertFalse(info.sources.isEmpty, info.name)
        }
    }

    func testTestosteroneClaimsAreHedgedOrGone() throws {
        let fat = try XCTUnwrap(NutrientInfo.forLabel("Fat"))
        XCTAssertTrue(fat.why.contains("some evidence"))
        XCTAssertFalse(fat.why.contains("Very low-fat diets lower testosterone in men."))
        let zinc = try XCTUnwrap(NutrientInfo.forLabel("Zinc"))
        XCTAssertFalse(zinc.why.lowercased().contains("testosterone"))
    }
}
