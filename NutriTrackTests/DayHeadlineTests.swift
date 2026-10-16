import XCTest
@testable import NutriTrack

final class DayHeadlineTests: XCTestCase {

    private let walk = DayHeadline.Session(name: "Walk", isStrength: false, plannedMinutes: 25, adjustedMinutes: 25)

    func testWithoutACheckInItAsksForOne() {
        let headline = DayHeadline.make(.init(hasCheckIn: false))
        XCTAssertEqual(headline, DayHeadline(eyebrow: "Morning", title: "How did you sleep?",
                                             reason: "Check in to get today's read."))
    }

    func testGreenDayWithASession() {
        let headline = DayHeadline.make(.init(color: .green, sleepHours: 7.5, energy: 4, session: walk))
        XCTAssertEqual(headline.eyebrow, "Good to go")
        XCTAssertEqual(headline.title, "Ready to move.")
        XCTAssertEqual(headline.reason, "You slept 7.5 h and energy is 4 of 5. A good day for the walk.")
    }

    func testGreenDayWithStrength() {
        let strength = DayHeadline.Session(name: "Strength", isStrength: true, plannedMinutes: 20, adjustedMinutes: 20)
        let headline = DayHeadline.make(.init(color: .green, sleepHours: 8, energy: 5, session: strength))
        XCTAssertEqual(headline.reason, "You slept 8 h and energy is 5 of 5. A good day for strength.")
    }

    func testGreenDayWithNothingPlanned() {
        let headline = DayHeadline.make(.init(color: .green, sleepHours: 7.25, energy: 3))
        XCTAssertEqual(headline.title, "Rested and steady.")
        XCTAssertEqual(headline.reason, "You slept 7.25 h and energy is 3 of 5. Nothing planned today.")
    }

    func testYellowDayNamesTheShorterSession() {
        let long = DayHeadline.Session(name: "Hike", isStrength: false, plannedMinutes: 60, adjustedMinutes: 45)
        let headline = DayHeadline.make(.init(color: .yellow, sleepHours: 5.5, energy: 3, session: long))
        XCTAssertEqual(headline.eyebrow, "Easy day")
        XCTAssertEqual(headline.title, "Take it easy today.")
        XCTAssertEqual(headline.reason, "You slept 5.5 h and energy is 3 of 5. The hike is shortened to 45 min.")
    }

    func testYellowDayKeepsAnUnchangedSessionEasy() {
        let headline = DayHeadline.make(.init(color: .yellow, sleepHours: 6, energy: 3, session: walk))
        XCTAssertEqual(headline.reason, "You slept 6 h and energy is 3 of 5. Keep the walk easy.")
    }

    func testYellowDayWithStrength() {
        let strength = DayHeadline.Session(name: "Strength", isStrength: true, plannedMinutes: 20, adjustedMinutes: 20)
        let headline = DayHeadline.make(.init(color: .yellow, sleepHours: 6, energy: 2, session: strength))
        XCTAssertEqual(headline.reason, "You slept 6 h and energy is 2 of 5. Strength is lighter today.")
    }

    func testRedDayWhenIll() {
        let headline = DayHeadline.make(.init(color: .red, sleepHours: 8, energy: 2, isSick: true, session: walk))
        XCTAssertEqual(headline.eyebrow, "Rest day")
        XCTAssertEqual(headline.title, "A day to recover.")
        XCTAssertEqual(headline.reason, "You marked yourself ill. Training is off today.")
    }

    func testRedDayWithPain() {
        let headline = DayHeadline.make(.init(color: .red, sleepHours: 8, energy: 4, hasPain: true))
        XCTAssertEqual(headline.title, "A day to recover.")
        XCTAssertEqual(headline.reason, "You marked pain that changes how you walk. Training is off today.")
    }

    func testFactsWithMissingData() {
        XCTAssertEqual(DayHeadline.make(.init(color: .green, sleepHours: 7)).reason, "You slept 7 h. Nothing planned today.")
        XCTAssertEqual(DayHeadline.make(.init(color: .green, energy: 4)).reason, "Energy is 4 of 5. Nothing planned today.")
        XCTAssertEqual(DayHeadline.make(.init(color: .green)).reason, "Nothing planned today.")
    }
    func testASessionAlreadyDoneIsSaidSo() {
        var done = walk
        done.isDone = true
        let headline = DayHeadline.make(.init(color: .green, sleepHours: 7.5, energy: 4, session: done))
        XCTAssertEqual(headline.title, "Ready to move.")
        XCTAssertEqual(headline.reason, "You slept 7.5 h and energy is 4 of 5. Today's walk is done.")
    }

    func testTheReasonCarriesTheCause() {
        let headline = DayHeadline.make(DayHeadline.Input(
            color: .yellow, sleepHours: 5.5, energy: 4, reasons: [.shortNight]))
        XCTAssertEqual(headline.eyebrow, "Easy day")
        XCTAssertTrue(headline.reason.contains("Short night"), headline.reason)
    }

    func testRestDayOnlyWithIllnessOrPain() {
        let ill = DayHeadline.make(DayHeadline.Input(color: .red, isSick: true, reasons: [.ill]))
        XCTAssertEqual(ill.eyebrow, "Rest day")
        let lowEnergy = DayHeadline.make(DayHeadline.Input(color: .yellow, energy: 2, reasons: [.lowEnergy(2)]))
        XCTAssertEqual(lowEnergy.eyebrow, "Easy day")
        XCTAssertTrue(lowEnergy.reason.contains("Energy is 2 of 5."), lowEnergy.reason)
    }

    func testAGreenDayHasNoCause() {
        let headline = DayHeadline.make(DayHeadline.Input(color: .green, sleepHours: 8, energy: 4, reasons: []))
        XCTAssertEqual(headline.eyebrow, "Good to go")
        XCTAssertFalse(headline.reason.contains("Short night"))
    }

    func testWithASuggestionTheHeadlinePointsToItAndDoesNotClaimTheChange() {
        var strength = DayHeadline.Session(name: "Strength", isStrength: true, plannedMinutes: 20, adjustedMinutes: 20)
        strength.hasSuggestion = true
        let headline = DayHeadline.make(.init(color: .yellow, energy: 2, reasons: [.lowEnergy(2)], session: strength))
        XCTAssertEqual(headline.reason, "Energy is 2 of 5. A lighter option is suggested below.")
    }

    func testStrengthKeptAsPlannedIsSaidSo() {
        var strength = DayHeadline.Session(name: "Strength", isStrength: true, plannedMinutes: 20, adjustedMinutes: 20)
        strength.isLighter = false
        let headline = DayHeadline.make(.init(color: .yellow, energy: 2, reasons: [.lowEnergy(2)], session: strength))
        XCTAssertEqual(headline.reason, "Energy is 2 of 5. Strength as planned.")
    }
}
