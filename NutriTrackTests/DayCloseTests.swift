import XCTest
import CoreData
@testable import NutriTrack

@MainActor
final class DayCloseTests: XCTestCase {

    private let calendar = Calendar.current
    private var now: Date { calendar.date(bySettingHour: 12, minute: 0, second: 0, of: Date())! }
    private func day(_ offset: Int) -> Date { calendar.date(byAdding: .day, value: offset, to: now)! }
    private func score(_ value: Int) -> HealthScore { HealthScore(value: value, components: []) }

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

    private func component(_ label: String, in score: HealthScore) -> Double {
        score.components.first { $0.label == label }?.score ?? -1
    }

    func testLiveDietScoreNeedsFood() {
        let (ctx, profile) = makeStore()
        XCTAssertNil(EvaluationService.computeTodayScores(profile: profile, in: ctx).diet)
        addMeal(ctx, at: Date(), calories: 400)
        XCTAssertNotNil(EvaluationService.computeTodayScores(profile: profile, in: ctx).diet)
    }

    func testSmallBalancedMealScoresWellWhileOpenAndLowOnceClosed() throws {
        let (ctx, profile) = makeStore()
        let targets = profile.macroTargets
        addMeal(ctx, at: Date(), calories: targets.calories * 0.25, proteinG: targets.proteinG * 0.25)
        let live = try XCTUnwrap(EvaluationService.computeTodayScores(profile: profile, in: ctx).diet)
        XCTAssertEqual(component("Protein", in: live), 1, accuracy: 0.001)
        XCTAssertEqual(component("Calories", in: live), 1, accuracy: 0.001)

        XCTAssertTrue(EvaluationService.closeDay(Date(), profile: profile, isLogComplete: true, in: ctx))
        let closed = try XCTUnwrap(EvaluationService.computeTodayScores(profile: profile, in: ctx).diet)
        XCTAssertEqual(component("Protein", in: closed), 0.25, accuracy: 0.001)
        XCTAssertEqual(component("Calories", in: closed), 0, accuracy: 0.001)
    }

    func testCloseDayStoresTheFinalScoreAndTheMarks() throws {
        let (ctx, profile) = makeStore()
        addMeal(ctx, at: Date(), calories: profile.macroTargets.calories, proteinG: profile.macroTargets.proteinG)
        let closedAt = Date(timeIntervalSince1970: 1_800_000_000)
        XCTAssertTrue(EvaluationService.closeDay(Date(), profile: profile, isLogComplete: true, now: closedAt, in: ctx))
        let evaluation = try XCTUnwrap(EvaluationService.todayEvaluation(in: ctx))
        let expected = try XCTUnwrap(EvaluationService.dietScore(for: Date(), profile: profile, isClosed: true, in: ctx))
        XCTAssertEqual(Int(evaluation.dietScore), expected.value)
        XCTAssertGreaterThan(evaluation.dietScore, 0)
        XCTAssertEqual(evaluation.closedAt, closedAt)
        XCTAssertTrue(evaluation.isLogComplete)
        XCTAssertNil(evaluation.generatedAt)
    }

    func testADayWithoutFoodIsNotClosed() {
        let (ctx, profile) = makeStore()
        XCTAssertFalse(EvaluationService.closeDay(Date(), profile: profile, isLogComplete: true, in: ctx))
        XCTAssertNil(EvaluationService.todayEvaluation(in: ctx))
    }

    func testAutoCloseClosesMissedDaysThatHaveFood() throws {
        let (ctx, profile) = makeStore()
        for offset in [0, -1, -3, -20] { addMeal(ctx, at: day(offset), calories: 500) }
        let closed = EvaluationService.autoCloseMissedDays(profile: profile, now: now, in: ctx)
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
        let (ctx, profile) = makeStore()
        addMeal(ctx, at: day(-1), calories: 500)
        EvaluationService.closeDay(day(-1), profile: profile, isLogComplete: true, in: ctx)
        XCTAssertTrue(EvaluationService.autoCloseMissedDays(profile: profile, now: now, in: ctx).isEmpty)
        XCTAssertEqual(EvaluationService.evaluation(for: day(-1), in: ctx)?.isLogComplete, true)
    }

    func testChangingMealsOnAClosedDayRecalculatesTheScore() throws {
        let (ctx, profile) = makeStore()
        let targets = profile.macroTargets
        let meal = addMeal(ctx, at: Date(), calories: targets.calories * 0.5, proteinG: targets.proteinG * 0.5)
        EvaluationService.closeDay(Date(), profile: profile, isLogComplete: true, in: ctx)
        let before = try XCTUnwrap(EvaluationService.todayEvaluation(in: ctx)).dietScore

        meal.calories = targets.calories
        meal.proteinG = targets.proteinG
        try ctx.save()
        EvaluationService.refreshClosedDay(containing: Date(), in: ctx)
        XCTAssertGreaterThan(try XCTUnwrap(EvaluationService.todayEvaluation(in: ctx)).dietScore, before)
    }

    func testRemovingEveryMealReopensTheDay() throws {
        let (ctx, profile) = makeStore()
        let meal = addMeal(ctx, at: Date(), calories: 900, proteinG: 60)
        EvaluationService.closeDay(Date(), profile: profile, isLogComplete: true, in: ctx)
        ctx.delete(meal)
        try ctx.save()
        EvaluationService.refreshClosedDay(containing: Date(), in: ctx)
        let evaluation = try XCTUnwrap(EvaluationService.todayEvaluation(in: ctx))
        XCTAssertNil(evaluation.closedAt)
        XCTAssertFalse(evaluation.isLogComplete)
        XCTAssertEqual(evaluation.dietScore, 0)
    }

    func testRefreshIgnoresDaysThatAreStillOpen() {
        let (ctx, _) = makeStore()
        addMeal(ctx, at: Date(), calories: 900)
        EvaluationService.refreshClosedDay(containing: Date(), in: ctx)
        XCTAssertNil(EvaluationService.todayEvaluation(in: ctx))
    }

    func testCheckInScoresDoNotTouchTheDietScore() throws {
        let (ctx, profile) = makeStore()
        addMeal(ctx, at: Date(), calories: profile.macroTargets.calories, proteinG: profile.macroTargets.proteinG)
        EvaluationService.closeDay(Date(), profile: profile, isLogComplete: true, in: ctx)
        let diet = try XCTUnwrap(EvaluationService.todayEvaluation(in: ctx)).dietScore

        EvaluationService.upsert(sleep: score(70), readiness: score(90), in: ctx)
        let evaluation = try XCTUnwrap(EvaluationService.todayEvaluation(in: ctx))
        XCTAssertEqual(evaluation.dietScore, diet)
        XCTAssertEqual(evaluation.sleepScore, 70)
        XCTAssertEqual(evaluation.readinessScore, 90)
        XCTAssertNotNil(evaluation.generatedAt)
        XCTAssertNotNil(evaluation.closedAt)
    }

    func testDietHistoryOnlyListsDaysClosedAsComplete() throws {
        let (ctx, profile) = makeStore()
        addMeal(ctx, at: day(-1), calories: 900)
        EvaluationService.closeDay(day(-1), profile: profile, isLogComplete: true, in: ctx)
        addMeal(ctx, at: day(-2), calories: 700)
        EvaluationService.closeDay(day(-2), profile: profile, isLogComplete: false, in: ctx)
        EvaluationService.upsert(sleep: score(70), readiness: score(90), in: ctx)

        let dietRequest = DailyEvaluation.fetchRequest()
        dietRequest.predicate = EvaluationService.dietHistoryPredicate(since: day(-14))
        let diet = try ctx.fetch(dietRequest)
        XCTAssertEqual(diet.map(\.date), [calendar.startOfDay(for: day(-1))])

        let otherRequest = DailyEvaluation.fetchRequest()
        otherRequest.predicate = EvaluationService.historyPredicate(since: day(-14))
        XCTAssertEqual(try ctx.fetch(otherRequest).map(\.date), [calendar.startOfDay(for: Date())])
    }

    func testDietSummaryNamesMealsAndTargets() throws {
        let (ctx, profile) = makeStore()
        addMeal(ctx, at: Date(), calories: 640, proteinG: 41, name: "Chicken and rice")
        let summary = try XCTUnwrap(EvaluationService.dietSummaryText(for: Date(), profile: profile, in: ctx))
        XCTAssertTrue(summary.contains("Chicken and rice"))
        XCTAssertTrue(summary.contains("Calories: 640 / \(Int(profile.macroTargets.calories)) kcal target"))
        XCTAssertNil(EvaluationService.dietSummaryText(for: day(-1), profile: profile, in: ctx))
    }

    func testWeekIntakesComeOnlyFromDaysClosedAsComplete() {
        let (ctx, profile) = makeStore()
        addMeal(ctx, at: day(-1), calories: 2000)
        addMeal(ctx, at: day(-2), calories: 1500)
        addMeal(ctx, at: day(-3), calories: 900)
        addMeal(ctx, at: day(-8), calories: 2600)
        EvaluationService.closeDay(day(-1), profile: profile, isLogComplete: true, in: ctx)
        EvaluationService.closeDay(day(-2), profile: profile, isLogComplete: true, in: ctx)
        EvaluationService.closeDay(day(-3), profile: profile, isLogComplete: false, in: ctx)
        EvaluationService.closeDay(day(-8), profile: profile, isLogComplete: true, in: ctx)

        let intakes = EvaluationService.completeDayIntakes(now: now, in: ctx)
        XCTAssertEqual(intakes.map(\.food.calories).sorted(), [1500, 2000])
        XCTAssertEqual(WeekIntake.average(intakes).total.calories, 1750, accuracy: 0.0001)
    }
}
