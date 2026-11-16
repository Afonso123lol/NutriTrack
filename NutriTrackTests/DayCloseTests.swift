import XCTest
import CoreData
@testable import NutriTrack

@MainActor
final class DayCloseTests: XCTestCase {

    private let calendar = Calendar.current
    private var now: Date { calendar.date(bySettingHour: 12, minute: 0, second: 0, of: Date())! }
    private func day(_ offset: Int) -> Date { calendar.date(byAdding: .day, value: offset, to: now)! }

    private func makeStore() -> (NSManagedObjectContext, UserProfile) {
        let ctx = Persistence(inMemory: true).container.viewContext
        let profile = UserProfile(context: ctx)
        profile.id = UUID()
        profile.sex = "male"
        profile.goal = "maintain"
        profile.age = 30
        profile.weightKg = 80
        profile.heightCm = 180
        try? ctx.save()
        return (ctx, profile)
    }

    @discardableResult
    private func addMeal(_ ctx: NSManagedObjectContext, at date: Date, calories: Double,
                         proteinG: Double = 0, name: String = "Meal") -> FoodEntry {
        let entry = FoodEntry(context: ctx)
        entry.id = UUID()
        entry.timestamp = date
        entry.dishName = name
        entry.calories = calories
        entry.proteinG = proteinG
        try? ctx.save()
        return entry
    }

    func testCloseDayStoresTheMarks() throws {
        let (ctx, _) = makeStore()
        addMeal(ctx, at: Date(), calories: 600, proteinG: 40)
        let closedAt = Date(timeIntervalSince1970: 1_800_000_000)
        XCTAssertTrue(EvaluationService.closeDay(Date(), isLogComplete: true, now: closedAt, in: ctx))
        let evaluation = try XCTUnwrap(EvaluationService.todayEvaluation(in: ctx))
        XCTAssertEqual(evaluation.closedAt, closedAt)
        XCTAssertTrue(evaluation.isLogComplete)
        XCTAssertEqual(evaluation.dietScore, 0)
        XCTAssertNil(evaluation.generatedAt)
    }

    func testADayWithoutFoodIsNotClosed() {
        let (ctx, _) = makeStore()
        XCTAssertFalse(EvaluationService.closeDay(Date(), isLogComplete: true, in: ctx))
        XCTAssertNil(EvaluationService.todayEvaluation(in: ctx))
    }

    func testADayWithZeroCalorieFoodStillCloses() {
        let (ctx, _) = makeStore()
        addMeal(ctx, at: Date(), calories: 0, name: "Black coffee")
        XCTAssertTrue(EvaluationService.closeDay(Date(), isLogComplete: true, in: ctx))
    }

    func testAutoCloseClosesMissedDaysThatHaveFood() throws {
        let (ctx, _) = makeStore()
        for offset in [0, -1, -3, -20] { addMeal(ctx, at: day(offset), calories: 500) }
        let closed = EvaluationService.autoCloseMissedDays(now: now, in: ctx)
        XCTAssertEqual(closed, [-1, -3].map { calendar.startOfDay(for: day($0)) })
        let yesterday = try XCTUnwrap(EvaluationService.evaluation(for: day(-1), in: ctx))
        XCTAssertNotNil(yesterday.closedAt)
        XCTAssertFalse(yesterday.isLogComplete)
        XCTAssertNotNil(EvaluationService.evaluation(for: day(-3), in: ctx)?.closedAt)
        XCTAssertNil(EvaluationService.evaluation(for: day(-2), in: ctx))
        XCTAssertNil(EvaluationService.evaluation(for: day(-20), in: ctx))
        XCTAssertNil(EvaluationService.evaluation(for: day(0), in: ctx)?.closedAt)
    }

    func testAutoCloseLeavesClosedDaysAlone() {
        let (ctx, _) = makeStore()
        addMeal(ctx, at: day(-1), calories: 500)
        EvaluationService.closeDay(day(-1), isLogComplete: true, in: ctx)
        XCTAssertTrue(EvaluationService.autoCloseMissedDays(now: now, in: ctx).isEmpty)
        XCTAssertEqual(EvaluationService.evaluation(for: day(-1), in: ctx)?.isLogComplete, true)
    }

    func testChangingMealsOnAClosedDayKeepsItClosed() throws {
        let (ctx, _) = makeStore()
        let meal = addMeal(ctx, at: Date(), calories: 500)
        EvaluationService.closeDay(Date(), isLogComplete: true, in: ctx)
        meal.calories = 900
        try ctx.save()
        EvaluationService.refreshClosedDay(containing: Date(), in: ctx)
        let evaluation = try XCTUnwrap(EvaluationService.todayEvaluation(in: ctx))
        XCTAssertNotNil(evaluation.closedAt)
        XCTAssertTrue(evaluation.isLogComplete)
    }

    func testRemovingEveryMealReopensTheDay() throws {
        let (ctx, _) = makeStore()
        let meal = addMeal(ctx, at: Date(), calories: 900, proteinG: 60)
        EvaluationService.closeDay(Date(), isLogComplete: true, in: ctx)
        ctx.delete(meal)
        try ctx.save()
        EvaluationService.refreshClosedDay(containing: Date(), in: ctx)
        let evaluation = try XCTUnwrap(EvaluationService.todayEvaluation(in: ctx))
        XCTAssertNil(evaluation.closedAt)
        XCTAssertTrue(evaluation.isLogComplete)
    }

    func testACompleteDayThatSwapsItsOnlyMealStaysComplete() throws {
        let (ctx, _) = makeStore()
        let wrong = addMeal(ctx, at: day(-1), calories: 700)
        EvaluationService.closeDay(day(-1), isLogComplete: true, in: ctx)
        wrong.remove(from: ctx)
        XCTAssertNil(EvaluationService.evaluation(for: day(-1), in: ctx)?.closedAt)
        addMeal(ctx, at: day(-1), calories: 650)
        EvaluationService.autoCloseMissedDays(now: now, in: ctx)
        let evaluation = try XCTUnwrap(EvaluationService.evaluation(for: day(-1), in: ctx))
        XCTAssertNotNil(evaluation.closedAt)
        XCTAssertTrue(evaluation.isLogComplete)
    }

    func testADayWithOnlySupplementsIsNotClosed() {
        let (ctx, _) = makeStore()
        let log = SupplementLog(context: ctx)
        log.id = UUID()
        log.timestamp = day(-1)
        try? ctx.save()
        XCTAssertFalse(EvaluationService.closeDay(day(-1), isLogComplete: true, in: ctx))
        XCTAssertTrue(EvaluationService.autoCloseMissedDays(now: now, in: ctx).isEmpty)
    }

    func testShiftingByDaysKeepsMidnightAcrossTheClockChange() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Europe/Lisbon"))
        let afterChange = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 4, day: 2)))
        let original = NSTimeZone.default
        NSTimeZone.default = calendar.timeZone
        defer { NSTimeZone.default = original }
        let weekBefore = TrainingService.shifted(afterChange, days: -7)
        XCTAssertEqual(Calendar.current.dateComponents([.hour, .day, .month], from: weekBefore),
                       DateComponents(month: 3, day: 26, hour: 0))
    }

    func testRefreshIgnoresDaysThatAreStillOpen() {
        let (ctx, _) = makeStore()
        addMeal(ctx, at: Date(), calories: 900)
        EvaluationService.refreshClosedDay(containing: Date(), in: ctx)
        XCTAssertNil(EvaluationService.todayEvaluation(in: ctx))
    }

    func testDietHistoryOnlyListsDaysClosedAsComplete() throws {
        let (ctx, _) = makeStore()
        addMeal(ctx, at: day(-1), calories: 900)
        EvaluationService.closeDay(day(-1), isLogComplete: true, in: ctx)
        addMeal(ctx, at: day(-2), calories: 700)
        EvaluationService.closeDay(day(-2), isLogComplete: false, in: ctx)

        let request = DailyEvaluation.fetchRequest()
        request.predicate = EvaluationService.dietHistoryPredicate(since: day(-14))
        XCTAssertEqual(try ctx.fetch(request).map(\.date), [calendar.startOfDay(for: day(-1))])
    }

    func testWeekIntakesComeOnlyFromDaysClosedAsComplete() {
        let (ctx, _) = makeStore()
        addMeal(ctx, at: day(-1), calories: 2000)
        addMeal(ctx, at: day(-2), calories: 1500)
        addMeal(ctx, at: day(-3), calories: 900)
        addMeal(ctx, at: day(-8), calories: 2600)
        EvaluationService.closeDay(day(-1), isLogComplete: true, in: ctx)
        EvaluationService.closeDay(day(-2), isLogComplete: true, in: ctx)
        EvaluationService.closeDay(day(-3), isLogComplete: false, in: ctx)
        EvaluationService.closeDay(day(-8), isLogComplete: true, in: ctx)

        let intakes = EvaluationService.completeDayIntakes(now: now, in: ctx)
        XCTAssertEqual(intakes.map(\.food.calories).sorted(), [1500, 2000])
        XCTAssertEqual(WeekIntake.average(intakes).total.calories, 1750, accuracy: 0.0001)
    }

    func testFoodWeekDaysCarryTheLongSessionMark() {
        let (ctx, _) = makeStore()
        addMeal(ctx, at: day(-1), calories: 2000, proteinG: 120)
        addMeal(ctx, at: day(-2), calories: 1500)
        addMeal(ctx, at: day(-3), calories: 900)
        TrainingService.logAerobic(modality: .walk, durationMin: 150, rpe: 3, at: day(-2), in: ctx)
        EvaluationService.closeDay(day(-1), isLogComplete: true, in: ctx)
        EvaluationService.closeDay(day(-2), isLogComplete: true, in: ctx)
        EvaluationService.closeDay(day(-3), isLogComplete: false, in: ctx)

        let days = EvaluationService.foodWeekDays(now: now, in: ctx).sorted { $0.calories < $1.calories }
        XCTAssertEqual(days.map(\.calories), [1500, 2000])
        XCTAssertEqual(days.map(\.hasLongSession), [true, false])
        XCTAssertEqual(days.last?.proteinG, 120)
    }
}
