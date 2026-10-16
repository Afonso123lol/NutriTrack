import XCTest
import CoreData
@testable import NutriTrack

@MainActor
final class SleepNeedTests: XCTestCase {

    func testStoredValueIsKeptInsideSevenToTenHours() {
        XCTAssertEqual(SleepNeed.resolved(8.3), 8.3)
        XCTAssertEqual(SleepNeed.resolved(6), 7)
        XCTAssertEqual(SleepNeed.resolved(11), 10)
    }

    func testMissingValueFallsBackToEightHours() {
        XCTAssertEqual(SleepNeed.resolved(0), 8)
        XCTAssertEqual(SleepNeed.resolved(-1), 8)
    }

    func testANewProfileNeedsEightHours() {
        let ctx = Persistence(inMemory: true).container.viewContext
        let profile = UserProfile(context: ctx)
        XCTAssertEqual(profile.sleepNeed, 8)
        profile.sleepNeedHours = 9.5
        XCTAssertEqual(profile.sleepNeed, 9.5)
    }

    func testTheQuestionIsTheOneFromTheAthleteStudy() {
        XCTAssertEqual(SleepNeed.question, "How many hours of sleep do you need to feel rested?")
    }
}
