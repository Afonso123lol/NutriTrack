import XCTest
@testable import NutriTrack

final class NutrientStatusTests: XCTestCase {

    func testBelowMinimumIsLow() {
        XCTAssertEqual(NutrientStatus.of(value: 5, min: 10, max: 100, invert: false), .low)
    }

    func testWithinRangeIsGood() {
        XCTAssertEqual(NutrientStatus.of(value: 50, min: 10, max: 100, invert: false), .good)
    }

    func testAboveMaximumIsOver() {
        XCTAssertEqual(NutrientStatus.of(value: 150, min: 10, max: 100, invert: false), .over)
    }

    func testExactlyAtMaximumIsGood() {
        XCTAssertEqual(NutrientStatus.of(value: 100, min: 10, max: 100, invert: false), .good)
    }

    func testInvertedApproachingMaximumWarns() {
        XCTAssertEqual(NutrientStatus.of(value: 90, min: 0, max: 100, invert: true), .low)
    }

    func testInvertedWellUnderIsGood() {
        XCTAssertEqual(NutrientStatus.of(value: 10, min: 0, max: 100, invert: true), .good)
    }

    func testInvertedOverMaximumIsOver() {
        XCTAssertEqual(NutrientStatus.of(value: 120, min: 0, max: 100, invert: true), .over)
    }

    func testZeroMaximumDoesNotCrash() {
        XCTAssertEqual(NutrientStatus.of(value: 0, min: 0, max: 0, invert: false), .good)
    }

    func testZeroMaximumWithIntakeClampsDenominatorToOne() {
        XCTAssertEqual(NutrientStatus.of(value: 5, min: 0, max: 0, invert: false), .over)
        XCTAssertEqual(NutrientStatus.of(value: 0.5, min: 0, max: 0, invert: true), .good)
    }

    func testFractionalMaximumClampsDenominatorToOne() {
        XCTAssertEqual(NutrientStatus.of(value: 0.9, min: 0, max: 0.5, invert: false), .good)
        XCTAssertEqual(NutrientStatus.of(value: 0.9, min: 0, max: 0.5, invert: true), .low)
    }

    func testSupplementOnlyLimitIgnoresFood() {
        XCTAssertEqual(NutrientStatus.of(value: 600, min: 420, supplemental: 200, supplementalMax: 350), .good)
        XCTAssertEqual(NutrientStatus.of(value: 600, min: 420, supplemental: 400, supplementalMax: 350), .over)
        XCTAssertEqual(NutrientStatus.of(value: 300, min: 420, supplemental: 0, supplementalMax: 350), .low)
        XCTAssertEqual(NutrientStatus.of(value: 350, min: 420, supplemental: 350, supplementalMax: 350), .low)
    }

    func testUpperLevelsThatCountSupplementsOnly() {
        let limits = NutrientLimits.calculate(sex: .male, age: 30, weightKg: 80, goal: .maintain, targetCalories: 2500)
        for reference in [limits.magnesium, limits.vitaminB3, limits.folate, limits.vitaminA] {
            XCTAssertEqual(reference.upperScope, .supplementsOnly)
        }
        XCTAssertEqual(limits.vitaminE.upperScope, .total)
    }
}
