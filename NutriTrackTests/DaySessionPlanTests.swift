import XCTest
@testable import NutriTrack

final class DaySessionPlanTests: XCTestCase {

    private func plan(color: DayColor, mode: YellowMode = .suggest, choice: SuggestionChoice? = nil,
                      kind: SessionKind = .long, badDays: Int = 0) -> DaySessionPlan {
        DaySessionPlan.make(kind: kind, targetMinutes: 60, strengthSets: 3, color: color,
                         weekBadDays: badDays, mode: mode, choice: choice)
    }

    func testOnAYellowDayTheSuggestionIsOfferedAndThePlanStands() {
        let result = plan(color: .yellow)
        XCTAssertEqual(result.applied.targetMinutes, 60)
        XCTAssertEqual(result.suggestion?.targetMinutes, 45)
        XCTAssertTrue(result.applied.countsForProgression)
    }

    func testAcceptingTheSuggestionAppliesIt() {
        let result = plan(color: .yellow, choice: .applied)
        XCTAssertEqual(result.applied.targetMinutes, 45)
        XCTAssertNil(result.suggestion)
    }

    func testKeepingThePlanLeavesItAlone() {
        let result = plan(color: .yellow, choice: .kept)
        XCTAssertEqual(result.applied.targetMinutes, 60)
        XCTAssertNil(result.suggestion)
    }

    func testInAutomaticModeTheYellowDayChangesThePlanWithoutAsking() {
        let result = plan(color: .yellow, mode: .auto)
        XCTAssertEqual(result.applied.targetMinutes, 45)
        XCTAssertNil(result.suggestion)
    }

    func testWithTheRuleOffAYellowDayChangesNothing() {
        let result = plan(color: .yellow, mode: .off)
        XCTAssertEqual(result.applied.targetMinutes, 60)
        XCTAssertNil(result.suggestion)
    }

    func testStrengthOnlyStopsCountingWhenTheSuggestionIsAccepted() {
        XCTAssertTrue(plan(color: .yellow, kind: .strength).applied.countsForProgression)
        XCTAssertFalse(plan(color: .yellow, choice: .applied, kind: .strength).applied.countsForProgression)
    }

    func testARedDayTurnsTrainingOffWhateverTheMode() {
        for mode in YellowMode.allCases {
            XCTAssertTrue(plan(color: .red, mode: mode).applied.isRest, mode.rawValue)
            XCTAssertNil(plan(color: .red, mode: mode).suggestion)
        }
    }

    func testAGreenDayWithThreeLowDaysIsNotTouchedByTheYellowRule() {
        let result = plan(color: .green, badDays: 3)
        XCTAssertEqual(result.applied.targetMinutes, 35)
        XCTAssertNil(result.suggestion)
    }

    func testAnEasySessionThatWouldNotChangeOffersNoSuggestion() {
        let result = plan(color: .yellow, kind: .easy)
        XCTAssertEqual(result.applied.targetMinutes, 60)
        XCTAssertNil(result.suggestion)
    }

    func testTheSuggestionTextSaysWhatChanges() {
        let long = plan(color: .yellow, kind: .long)
        XCTAssertEqual(long.suggestionText(kind: .long, plannedMinutes: 60, plannedSets: 0),
                       "Suggested: 45 min instead of 60.")
        let strength = DaySessionPlan.make(kind: .strength, targetMinutes: 30, strengthSets: 3, color: .yellow,
                                           weekBadDays: 0, mode: .suggest, choice: nil)
        XCTAssertEqual(strength.suggestionText(kind: .strength, plannedMinutes: 30, plannedSets: 3),
                       "Suggested: 2 sets instead of 3, with one more rep in reserve.")
        let single = DaySessionPlan.make(kind: .strength, targetMinutes: 30, strengthSets: 1, color: .yellow,
                                         weekBadDays: 0, mode: .suggest, choice: nil)
        XCTAssertEqual(single.suggestionText(kind: .strength, plannedMinutes: 30, plannedSets: 1),
                       "Suggested: one more rep in reserve on every set.")
        XCTAssertNil(plan(color: .green).suggestionText(kind: .long, plannedMinutes: 60, plannedSets: 0))
    }

    func testWithASingleSetTheNoteOnlyTalksAboutTheRepInReserve() {
        let single = SessionAdjuster.adjust(kind: .strength, targetMinutes: 20, strengthSets: 1, color: .yellow,
                                            weekBadDays: 0)
        XCTAssertEqual(single.note, "One more rep in reserve. Today does not count for progression.")
        let three = SessionAdjuster.adjust(kind: .strength, targetMinutes: 20, strengthSets: 3, color: .yellow,
                                           weekBadDays: 0)
        XCTAssertEqual(three.note, "One set less and one more rep in reserve. Today does not count for progression.")
    }

    func testInALighterWeekAYellowDayNeverGoesBackToTheFullPlan() {
        let kept = plan(color: .yellow, choice: .kept, badDays: 3)
        XCTAssertEqual(kept.applied.targetMinutes, 35)
        let open = plan(color: .yellow, badDays: 3)
        XCTAssertEqual(open.applied.targetMinutes, 35)
        XCTAssertNil(open.suggestion)
        let off = plan(color: .yellow, mode: .off, badDays: 3)
        XCTAssertEqual(off.applied.targetMinutes, 35)
    }
}
