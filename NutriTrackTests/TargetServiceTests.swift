import XCTest
import CoreData
@testable import NutriTrack

@MainActor
final class TargetServiceTests: XCTestCase {

    private let calendar = Calendar.current
    private var now: Date { calendar.date(bySettingHour: 12, minute: 0, second: 0, of: Date())! }
    private func day(_ offset: Int) -> Date { calendar.date(byAdding: .day, value: offset, to: now)! }

    private func makeStore(goal: Goal = .loseFat, weight: Double = 100) -> (NSManagedObjectContext, UserProfile) {
        let ctx = Persistence(inMemory: true).container.viewContext
        let profile = UserProfile(context: ctx)
        profile.id = UUID()
        profile.sex = "male"
        profile.goal = goal.rawValue
        profile.age = 30
        profile.weightKg = weight
        profile.heightCm = 180
        try? ctx.save()
        return (ctx, profile)
    }

    private func addWeighIns(_ ctx: NSManagedObjectContext, from start: Double, perDay: Double) {
        for offset in stride(from: -27, through: 0, by: 2) {
            let entry = WeightEntry(context: ctx)
            entry.id = UUID()
            entry.date = day(offset).addingTimeInterval(-3 * 3600)
            entry.weightKg = start + perDay * Double(offset + 27)
        }
        try? ctx.save()
    }

    private func addCompleteDays(_ ctx: NSManagedObjectContext, calories: Double, skipping: (Int) -> Bool = { _ in false }) {
        for offset in -27...(-1) where !skipping(offset) {
            let meal = FoodEntry(context: ctx)
            meal.id = UUID()
            meal.timestamp = day(offset)
            meal.calories = calories
            let evaluation = DailyEvaluation(context: ctx)
            evaluation.id = UUID()
            evaluation.date = calendar.startOfDay(for: day(offset))
            evaluation.closedAt = day(offset)
            evaluation.isLogComplete = true
        }
        try? ctx.save()
    }

    private var formulaTDEE: Double {
        BodyMetrics.restingRate(sex: .male, age: 30, weightKg: 100, heightCm: 180) * 1.55
    }

    func testWeekStartsOnMonday() {
        let monday = TargetService.weekStart(for: now)
        var iso = Calendar(identifier: .iso8601)
        iso.timeZone = .current
        XCTAssertEqual(iso.component(.weekday, from: monday), 2)
        XCTAssertLessThanOrEqual(monday, now)
        XCTAssertLessThan(now.timeIntervalSince(monday), 7 * 86400)
    }

    func testWithoutDataTheSnapshotUsesTheFormula() throws {
        let (ctx, profile) = makeStore()
        let snapshot = try XCTUnwrap(TargetService.refresh(profile: profile, now: now, in: ctx))
        XCTAssertEqual(snapshot.tdeeSource, "formula")
        XCTAssertEqual(snapshot.tdee, formulaTDEE, accuracy: 0.5)
        XCTAssertEqual(snapshot.trendWeightKg, 100)
        XCTAssertFalse(snapshot.hasMeasuredRate)
        XCTAssertEqual(snapshot.weekStart, TargetService.weekStart(for: now))
        XCTAssertEqual(snapshot.goal, "loseFat")
        XCTAssertEqual(snapshot.calories, formulaTDEE - 0.005 * 100 * 7700 / 7, accuracy: 0.5)
    }

    func testOneSnapshotPerWeekUnlessForced() throws {
        let (ctx, profile) = makeStore()
        let first = try XCTUnwrap(TargetService.refresh(profile: profile, now: now, in: ctx))
        let second = try XCTUnwrap(TargetService.refresh(profile: profile, now: now, in: ctx))
        XCTAssertEqual(first.objectID, second.objectID)

        profile.goal = Goal.maintain.rawValue
        let forced = try XCTUnwrap(TargetService.refresh(profile: profile, now: now, force: true, in: ctx))
        XCTAssertEqual(forced.objectID, first.objectID)
        XCTAssertEqual(forced.goal, "maintain")
        XCTAssertEqual(forced.calories, formulaTDEE, accuracy: 0.5)
        XCTAssertEqual(try ctx.fetch(TargetSnapshot.fetchRequest()).count, 1)
    }

    func testProfileTargetsComeFromTheSnapshot() throws {
        let (ctx, profile) = makeStore()
        XCTAssertEqual(profile.macroTargets.calories, formulaTDEE - 0.005 * 100 * 7700 / 7, accuracy: 0.5)
        let snapshot = try XCTUnwrap(TargetService.refresh(profile: profile, now: now, in: ctx))
        snapshot.calories = 2345
        snapshot.tdee = 2900
        try ctx.save()
        XCTAssertEqual(profile.macroTargets.calories, 2345)
        XCTAssertEqual(profile.macroTargets.fatG, 2345 * 0.30 / 9, accuracy: 0.5)

        profile.goal = Goal.maintain.rawValue
        XCTAssertEqual(profile.macroTargets.calories, formulaTDEE, accuracy: 0.5)
    }

    func testEnoughDataGivesAnAdaptiveEstimate() throws {
        let (ctx, profile) = makeStore()
        addWeighIns(ctx, from: 102.7, perDay: -0.1)
        addCompleteDays(ctx, calories: 2500)
        let snapshot = try XCTUnwrap(TargetService.refresh(profile: profile, now: now, in: ctx))
        let base = BodyMetrics.restingRate(sex: .male, age: 30, weightKg: snapshot.trendWeightKg, heightCm: 180) * 1.55
        let expected = min(base + 0.5 * (2500 + 770.0 - base), base + 150)
        XCTAssertEqual(snapshot.tdeeSource, "adaptive")
        XCTAssertEqual(snapshot.tdee, expected, accuracy: 1)
        XCTAssertTrue(snapshot.hasMeasuredRate)
        XCTAssertEqual(snapshot.measuredRateKgPerWeek, -0.7, accuracy: 0.01)
        XCTAssertEqual(snapshot.completeDays, 27)
        XCTAssertEqual(snapshot.weighIns, 14)
        XCTAssertEqual(snapshot.trendWeightKg, 100.9, accuracy: 0.5)
    }

    func testAutoClosedDaysDoNotCount() throws {
        let (ctx, profile) = makeStore()
        addWeighIns(ctx, from: 102.7, perDay: -0.1)
        addCompleteDays(ctx, calories: 2500)
        for evaluation in try ctx.fetch(DailyEvaluation.fetchRequest()) { evaluation.isLogComplete = false }
        try ctx.save()
        let snapshot = try XCTUnwrap(TargetService.refresh(profile: profile, now: now, in: ctx))
        XCTAssertEqual(snapshot.tdeeSource, "formula")
        XCTAssertEqual(snapshot.completeDays, 0)
    }

    func testARecentGoalChangeDelaysTheEstimate() throws {
        let (ctx, profile) = makeStore()
        profile.goalChangedAt = day(-20)
        addWeighIns(ctx, from: 102.7, perDay: -0.1)
        addCompleteDays(ctx, calories: 2500)
        let snapshot = try XCTUnwrap(TargetService.refresh(profile: profile, now: now, in: ctx))
        let base = BodyMetrics.restingRate(sex: .male, age: 30, weightKg: snapshot.trendWeightKg, heightCm: 180) * 1.55
        XCTAssertEqual(snapshot.tdeeSource, "formula")
        XCTAssertEqual(snapshot.tdee, base, accuracy: 0.5)
    }

    func testCaloriesMoveAtMostOneHundredAndFiftyBetweenWeeks() throws {
        let (ctx, profile) = makeStore()
        let previous = TargetSnapshot(context: ctx)
        previous.id = UUID()
        previous.weekStart = TargetService.weekStart(for: day(-7))
        previous.goal = "loseFat"
        previous.ratePercent = 0
        previous.calories = 3000
        previous.tdee = formulaTDEE
        previous.tdeeSource = "formula"
        try ctx.save()
        let snapshot = try XCTUnwrap(TargetService.refresh(profile: profile, now: now, in: ctx))
        XCTAssertEqual(snapshot.calories, 2850, accuracy: 0.5)

        profile.weeklyRatePercent = 0.25
        let changed = try XCTUnwrap(TargetService.refresh(profile: profile, now: now, force: true, in: ctx))
        XCTAssertEqual(changed.calories, formulaTDEE - 0.0025 * 100 * 7700 / 7, accuracy: 0.5)
    }

    func testInvalidProfileGivesNoSnapshot() {
        let (ctx, profile) = makeStore()
        profile.heightCm = 0
        XCTAssertNil(TargetService.refresh(profile: profile, now: now, in: ctx))
    }

    func testTrainingDayRaisesCarbsAndLowersFat() {
        let (_, profile) = makeStore(goal: .maintain, weight: 80)
        let rest = TargetService.dayTargets(for: profile, plannedMinutes: 0, hardEffort: false)
        XCTAssertNil(rest.carbMinimumG)
        XCTAssertEqual(rest.carbsG, profile.macroTargets.carbsG, accuracy: 0.01)

        let long = TargetService.dayTargets(for: profile, plannedMinutes: 200, hardEffort: false)
        XCTAssertEqual(long.carbMinimumG ?? 0, 6 * 80, accuracy: 0.01)
        XCTAssertGreaterThan(long.carbsG, rest.carbsG)
        XCTAssertLessThan(long.fatG, rest.fatG)

        let easyHour = TargetService.dayTargets(for: profile, plannedMinutes: 60, hardEffort: false)
        let hardHour = TargetService.dayTargets(for: profile, plannedMinutes: 60, hardEffort: true)
        XCTAssertEqual(easyHour.carbMinimumG ?? 0, 4 * 80, accuracy: 0.01)
        XCTAssertEqual(hardHour.carbMinimumG ?? 0, 5 * 80, accuracy: 0.01)
    }

    func testWeighInsAreClassifiedFromCheckInsMealsAndSessions() {
        let (ctx, _) = makeStore()
        func at(_ offset: Int, _ hour: Int, _ minute: Int = 0) -> Date {
            calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day(offset))!
        }
        func weighIn(_ date: Date) {
            let entry = WeightEntry(context: ctx)
            entry.id = UUID()
            entry.date = date
            entry.weightKg = 100
        }
        func meal(_ date: Date) {
            let entry = FoodEntry(context: ctx)
            entry.id = UUID()
            entry.timestamp = date
            entry.calories = 500
        }

        let checkIn = DailyCheckIn(context: ctx)
        checkIn.id = UUID()
        checkIn.date = calendar.startOfDay(for: day(-1))
        checkIn.wakeTime = at(-1, 7, 30)
        meal(at(-1, 9))
        weighIn(at(-1, 8))

        meal(at(-2, 13))
        weighIn(at(-2, 18))

        let session = TrainingSession(context: ctx)
        session.id = UUID()
        session.startedAt = at(-3, 18, 30)
        session.durationMin = 45
        meal(at(-3, 13))
        weighIn(at(-3, 19, 30))
        try? ctx.save()

        let contexts = TargetService.fetchWeighIns(since: day(-10), in: ctx)
            .sorted { $0.date < $1.date }
            .map(\.context)
        XCTAssertEqual(contexts, [.afterTraining, .daytime, .fasted])
    }

    func testWakeTimeComesFromBedtimePlusSleepWhenThatIsEarlier() {
        let (ctx, _) = makeStore()
        let start = calendar.startOfDay(for: day(-1))
        let checkIn = DailyCheckIn(context: ctx)
        checkIn.id = UUID()
        checkIn.date = start
        checkIn.bedtime = start.addingTimeInterval(-3600)
        checkIn.sleepHours = 7
        checkIn.wakeTime = start.addingTimeInterval(13 * 3600)
        let entry = WeightEntry(context: ctx)
        entry.id = UUID()
        entry.date = start.addingTimeInterval(12 * 3600)
        entry.weightKg = 100
        try? ctx.save()

        XCTAssertEqual(TargetService.fetchWeighIns(since: day(-10), in: ctx).map(\.context), [.daytime])
    }
}
