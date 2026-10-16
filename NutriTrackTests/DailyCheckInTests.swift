import XCTest
import CoreData
@testable import NutriTrack

@MainActor
final class DailyCheckInTests: XCTestCase {

    func testCreateStoresEveryAnswerAndTheRealWakeTime() throws {
        let ctx = Persistence(inMemory: true).container.viewContext
        let now = Date(timeIntervalSince1970: 1_790_000_000)
        let wokeAt = now.addingTimeInterval(-3600)
        let bedtime = wokeAt.addingTimeInterval(-7.25 * 3600)
        var answers = CheckInAnswers(wakeTime: wokeAt)
        answers.energy = 4
        answers.quality = 3
        answers.soreness = 2
        answers.stress = 5
        answers.sleepHours = 7.25
        answers.hasPain = true

        DailyCheckIn.create(answers, bedtime: bedtime, now: now, in: ctx)

        let saved = try XCTUnwrap(try ctx.fetch(DailyCheckIn.fetchRequest()).first)
        XCTAssertNotNil(saved.id)
        XCTAssertEqual(saved.date, Calendar.current.startOfDay(for: now))
        XCTAssertEqual(saved.energyLevel, 4)
        XCTAssertEqual(saved.sleepQuality, 3)
        XCTAssertEqual(saved.soreness, 2)
        XCTAssertEqual(saved.stress, 5)
        XCTAssertEqual(saved.sleepHours, 7.25)
        XCTAssertEqual(saved.wakeTime, wokeAt)
        XCTAssertEqual(saved.bedtime, bedtime)
        XCTAssertFalse(saved.isSick)
        XCTAssertTrue(saved.hasPain)
        XCTAssertEqual(saved.dayEnergy, 0)
    }

    private func makeCheckIn(on day: Date, in ctx: NSManagedObjectContext) -> DailyCheckIn {
        let checkIn = DailyCheckIn(context: ctx)
        checkIn.id = UUID()
        checkIn.date = Calendar.current.startOfDay(for: day)
        checkIn.energyLevel = 4
        return checkIn
    }

    func testCheckInIsFoundByItsDay() {
        let ctx = Persistence(inMemory: true).container.viewContext
        let today = Date()
        let yesterday = today.addingTimeInterval(-86400)
        let saved = makeCheckIn(on: yesterday, in: ctx)
        try? ctx.save()
        XCTAssertEqual(DailyCheckIn.on(yesterday, in: ctx)?.id, saved.id)
        XCTAssertNil(DailyCheckIn.on(today, in: ctx))
    }

    func testDayEnergyIsSavedOnlyFromOneToFive() {
        let ctx = Persistence(inMemory: true).container.viewContext
        let checkIn = makeCheckIn(on: Date(), in: ctx)
        checkIn.recordDayEnergy(0, in: ctx)
        XCTAssertEqual(checkIn.dayEnergy, 0)
        checkIn.recordDayEnergy(6, in: ctx)
        XCTAssertEqual(checkIn.dayEnergy, 0)
        checkIn.recordDayEnergy(4, in: ctx)
        XCTAssertEqual(checkIn.dayEnergy, 4)
        XCTAssertFalse(ctx.hasChanges)
    }

    func testTheCheckInBelongsToTheDayHeWokeUp() throws {
        let ctx = Persistence(inMemory: true).container.viewContext
        let now = Date(timeIntervalSince1970: 1_790_000_000)
        let wokeAt = now.addingTimeInterval(-26 * 3600)
        var answers = CheckInAnswers(wakeTime: wokeAt)
        answers.energy = 3
        answers.quality = 3
        answers.soreness = 1
        answers.stress = 1

        DailyCheckIn.create(answers, bedtime: nil, now: now, in: ctx)

        let saved = try XCTUnwrap(try ctx.fetch(DailyCheckIn.fetchRequest()).first)
        XCTAssertEqual(saved.date, Calendar.current.startOfDay(for: wokeAt))
    }

    func testTheSuggestionChoiceIsStoredOnTheDay() {
        let ctx = Persistence(inMemory: true).container.viewContext
        let checkIn = makeCheckIn(on: Date(), in: ctx)
        XCTAssertNil(checkIn.suggestionChoiceValue)
        checkIn.recordSuggestion(.applied, in: ctx)
        XCTAssertEqual(checkIn.suggestionChoiceValue, .applied)
        checkIn.recordSuggestion(.kept, in: ctx)
        XCTAssertEqual(checkIn.suggestionChoiceValue, .kept)
        XCTAssertFalse(ctx.hasChanges)
    }
}
