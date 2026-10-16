import XCTest
@testable import NutriTrack

final class GoalChoiceTests: XCTestCase {
    func testFourGoalsAreOfferedIncludingRecomposition() {
        XCTAssertEqual(Goal.offered, [.loseFat, .maintain, .recomp, .gainMuscle])
        XCTAssertEqual(Goal.offered.map(\.choiceName), ["Lose fat", "Maintain", "Recomposition", "Gain"])
        XCTAssertEqual(Goal.offered.map(\.shortName), ["Lose fat", "Maintain", "Recomp", "Gain"])
    }

    func testOlderGainWeightMapsToGain() {
        XCTAssertEqual(Goal.gainWeight.offeredEquivalent, .gainMuscle)
        XCTAssertEqual(Goal.recomp.offeredEquivalent, .recomp)
    }

    func testOnlyRecompositionAsksForHighProtein() {
        XCTAssertEqual(Goal.allCases.filter(\.prefersHighProtein), [.recomp])
        XCTAssertEqual(Goal.recomp.direction, .maintain)
    }

    func testRecompositionKeepsMaintenanceCaloriesWithCuttingProtein() {
        let maintain = TargetPlanner.plan(TargetInput(sex: .male, age: 22, weightKg: 75, heightCm: 180,
                                                      direction: .maintain, ratePercent: 0, tdee: 2800))
        let recomp = TargetPlanner.plan(TargetInput(sex: .male, age: 22, weightKg: 75, heightCm: 180,
                                                    direction: .maintain, ratePercent: 0, tdee: 2800,
                                                    highProtein: true))
        let cut = TargetPlanner.plan(TargetInput(sex: .male, age: 22, weightKg: 75, heightCm: 180,
                                                 direction: .lose, ratePercent: 0, tdee: 2800))
        XCTAssertEqual(recomp.calories, maintain.calories, accuracy: 0.5)
        XCTAssertGreaterThan(recomp.proteinG, maintain.proteinG)
        XCTAssertEqual(recomp.proteinG, cut.proteinG, accuracy: 5)
        XCTAssertEqual(recomp.direction, .maintain)
    }
}
