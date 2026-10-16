import XCTest
@testable import NutriTrack

final class BodyMetricsTests: XCTestCase {

    func testBodyMassIndex() {
        XCTAssertEqual(BodyMetrics.bmi(weightKg: 81, heightCm: 180), 25, accuracy: 0.001)
        XCTAssertEqual(BodyMetrics.bmi(weightKg: 138, heightCm: 180), 42.59, accuracy: 0.01)
        XCTAssertEqual(BodyMetrics.bmi(weightKg: 80, heightCm: 0), 0)
    }

    func testReferenceWeightIsCappedAtBodyMassIndexTwentyFive() {
        XCTAssertEqual(BodyMetrics.referenceWeight(weightKg: 138, heightCm: 180), 81, accuracy: 0.001)
        XCTAssertEqual(BodyMetrics.referenceWeight(weightKg: 70, heightCm: 180), 70, accuracy: 0.001)
    }

    func testFatFreeMassForMenAndWomen() {
        XCTAssertEqual(BodyMetrics.fatFreeMass(sex: .male, weightKg: 138, heightCm: 180), 80.56, accuracy: 0.05)
        XCTAssertEqual(BodyMetrics.fatFreeMass(sex: .male, weightKg: 80, heightCm: 180), 61.73, accuracy: 0.05)
        XCTAssertEqual(BodyMetrics.fatFreeMass(sex: .female, weightKg: 60, heightCm: 165), 39.29, accuracy: 0.05)
    }

    func testRestingRateMatchesMifflinStJeor() {
        XCTAssertEqual(BodyMetrics.restingRate(sex: .male, age: 25, weightKg: 80, heightCm: 180), 1805, accuracy: 0.001)
        XCTAssertEqual(BodyMetrics.restingRate(sex: .female, age: 30, weightKg: 60, heightCm: 165), 1320.25, accuracy: 0.001)
    }

    func testGoalDirections() {
        XCTAssertEqual(Goal.loseFat.direction, .lose)
        XCTAssertEqual(Goal.maintain.direction, .maintain)
        XCTAssertEqual(Goal.recomp.direction, .maintain)
        XCTAssertEqual(Goal.gainMuscle.direction, .gain)
        XCTAssertEqual(Goal.gainWeight.direction, .gain)
    }
}
