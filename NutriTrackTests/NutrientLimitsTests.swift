import XCTest
@testable import NutriTrack

final class NutrientLimitsTests: XCTestCase {

    private func limits(_ sex: Sex, _ age: Int, kcal: Double = 2500) -> NutrientLimits {
        NutrientLimits.calculate(sex: sex, age: age, weightKg: 70, goal: .maintain, targetCalories: kcal)
    }

    func testMineralsForAManOf22() {
        let man = limits(.male, 22)
        XCTAssertEqual(man.sodiumMaxMg, 2000)
        XCTAssertEqual(man.potassium, NutrientReference(reference: 3500))
        XCTAssertEqual(man.calcium, NutrientReference(reference: 1000, averageRequirement: 860, upper: 2500))
        XCTAssertEqual(man.iron, NutrientReference(reference: 11, averageRequirement: 6, upper: 40, isUpperSafeLevel: true))
        XCTAssertEqual(man.zinc, NutrientReference(reference: 11, upper: 25, source: .dri))
        XCTAssertEqual(man.magnesium, NutrientReference(reference: 350, upper: 250, upperScope: .supplementsOnly))
        XCTAssertEqual(man.phosphorus, NutrientReference(reference: 550, upper: 4000, upperSource: .dri))
        XCTAssertEqual(man.selenium, NutrientReference(reference: 70, upper: 255))
        XCTAssertEqual(man.copper, NutrientReference(reference: 1600, upper: 5000))
    }

    func testVitaminsForAManOf22() {
        let man = limits(.male, 22)
        XCTAssertEqual(man.vitaminA, NutrientReference(reference: 750, averageRequirement: 570, upper: 3000,
                                                       upperScope: .supplementsOnly))
        XCTAssertEqual(man.vitaminC, NutrientReference(reference: 110, averageRequirement: 90, upper: 2000, upperSource: .dri))
        XCTAssertEqual(man.vitaminD, NutrientReference(reference: 15, upper: 100))
        XCTAssertEqual(man.vitaminE, NutrientReference(reference: 13, upper: 300))
        XCTAssertEqual(man.vitaminK, NutrientReference(reference: 70))
        XCTAssertEqual(man.vitaminB2, NutrientReference(reference: 1.6, averageRequirement: 1.3))
        XCTAssertEqual(man.vitaminB5, NutrientReference(reference: 5))
        XCTAssertEqual(man.vitaminB6, NutrientReference(reference: 1.7, averageRequirement: 1.5, upper: 12))
        XCTAssertEqual(man.vitaminB12, NutrientReference(reference: 4))
        XCTAssertEqual(man.folate, NutrientReference(reference: 330, averageRequirement: 250, upper: 1000,
                                                     upperScope: .supplementsOnly))
    }

    func testThiamineAndNiacinFollowTheEnergyTarget() {
        let man = limits(.male, 22, kcal: 2500)
        XCTAssertEqual(man.vitaminB1.reference, 1.0468, accuracy: 0.001)
        XCTAssertEqual(man.vitaminB1.averageRequirement ?? 0, 0.7537, accuracy: 0.001)
        XCTAssertNil(man.vitaminB1.upper)
        XCTAssertEqual(man.vitaminB3.reference, 16.748, accuracy: 0.01)
        XCTAssertEqual(man.vitaminB3.averageRequirement ?? 0, 13.608, accuracy: 0.01)
        XCTAssertEqual(man.vitaminB3.upper, 35)
        XCTAssertEqual(man.vitaminB3.upperScope, .supplementsOnly)
        XCTAssertEqual(man.vitaminB3.upperSource, .dri)
        XCTAssertEqual(limits(.male, 22, kcal: 3000).vitaminB1.reference, 1.2561, accuracy: 0.001)
    }

    func testCalciumDropsAt25() {
        XCTAssertEqual(limits(.male, 24).calcium.reference, 1000)
        XCTAssertEqual(limits(.male, 25).calcium.reference, 950)
        XCTAssertEqual(limits(.female, 25).calcium.averageRequirement, 750)
    }

    func testValuesThatDifferForWomen() {
        let woman = limits(.female, 30)
        XCTAssertEqual(woman.iron, NutrientReference(reference: 16, averageRequirement: 7, upper: 40, isUpperSafeLevel: true))
        XCTAssertEqual(woman.zinc.reference, 8)
        XCTAssertEqual(woman.magnesium.reference, 300)
        XCTAssertEqual(woman.copper.reference, 1300)
        XCTAssertEqual(woman.vitaminA.reference, 650)
        XCTAssertEqual(woman.vitaminA.averageRequirement, 490)
        XCTAssertEqual(woman.vitaminC.reference, 95)
        XCTAssertEqual(woman.vitaminC.averageRequirement, 80)
        XCTAssertEqual(woman.vitaminE.reference, 11)
        XCTAssertEqual(woman.vitaminB6.reference, 1.6)
        XCTAssertEqual(woman.vitaminB6.averageRequirement, 1.3)
    }

    func testIronForWomenDropsAt51() {
        XCTAssertEqual(limits(.female, 50).iron.reference, 16)
        XCTAssertEqual(limits(.female, 51).iron.reference, 11)
        XCTAssertEqual(limits(.female, 51).iron.averageRequirement, 6)
    }

    func testPhosphorusUpperLevelDropsAfter70() {
        XCTAssertEqual(limits(.male, 70).phosphorus.upper, 4000)
        XCTAssertEqual(limits(.male, 71).phosphorus.upper, 3000)
    }

    func testFibreTargetScalesWithCalories() {
        XCTAssertEqual(limits(.male, 22, kcal: 3000).fiberMinG, 42, accuracy: 0.1)
    }

    func testBasisNamesTheSourceAndTheScope() {
        let man = limits(.male, 22)
        XCTAssertEqual(man.iron.basis, "Reference: EFSA. Safe level: EFSA.")
        XCTAssertEqual(man.zinc.basis, "Reference: DRI. Upper level: EFSA.")
        XCTAssertEqual(man.magnesium.basis, "Reference: EFSA. Upper level: EFSA, supplements only.")
        XCTAssertEqual(man.vitaminB3.basis, "Reference: EFSA. Upper level: DRI, supplements only.")
        XCTAssertEqual(man.potassium.basis, "Reference: EFSA. No upper level set.")
    }
}
