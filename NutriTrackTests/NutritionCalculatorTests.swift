import XCTest
@testable import NutriTrack

final class NutritionCalculatorTests: XCTestCase {

    func testMaleMuscleBuildingCalories() {
        let targets = NutritionCalculator.calculate(sex: .male, age: 25, weightKg: 80, heightCm: 180, goal: .gainMuscle)
        XCTAssertEqual(targets.calories, 2797.75 + 0.0025 * 80 * 7700 / 7, accuracy: 1.0)
    }

    func testProteinMinimumForMuscleGoal() {
        let targets = NutritionCalculator.calculate(sex: .male, age: 25, weightKg: 80, heightCm: 180, goal: .gainMuscle)
        XCTAssertGreaterThanOrEqual(targets.proteinG, 80 * 1.6)
    }

    func testCarbsNeverBelowBrainMinimum() {
        let targets = NutritionCalculator.calculate(sex: .male, age: 40, weightKg: 100, heightCm: 175, goal: .loseFat)
        XCTAssertGreaterThanOrEqual(targets.carbsG, 130.0)
    }

    func testFemalePreMenopauseIron() {
        let limits = NutrientLimits.calculate(sex: .female, age: 30, weightKg: 60, goal: .maintain, targetCalories: 2000)
        XCTAssertEqual(limits.iron.reference, 16.0)
    }

    func testFemalePostMenopauseIron() {
        let limits = NutrientLimits.calculate(sex: .female, age: 55, weightKg: 65, goal: .maintain, targetCalories: 1900)
        XCTAssertEqual(limits.iron.reference, 11.0)
    }

    func testFiberScalesWithCalories() {
        let limits = NutrientLimits.calculate(sex: .male, age: 25, weightKg: 80, goal: .gainMuscle, targetCalories: 3000)
        XCTAssertEqual(limits.fiberMinG, 42.0, accuracy: 0.1)
    }

    func testCaloriesNeverBelowMinimum() {
        let targets = NutritionCalculator.calculate(sex: .female, age: 25, weightKg: 40, heightCm: 150, goal: .loseFat)
        XCTAssertGreaterThanOrEqual(targets.calories, 1200.0)
    }
}
