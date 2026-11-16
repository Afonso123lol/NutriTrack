import XCTest
import CoreData
@testable import NutriTrack

@MainActor
final class TrainingServiceTests: XCTestCase {

    private var thisMonday: Date { TargetService.weekStart(for: Date()) }
    private var lastMonday: Date { Calendar.current.date(byAdding: .day, value: -7, to: thisMonday)! }
    private func at(_ monday: Date, day: Int, hour: Double = 10) -> Date {
        monday.addingTimeInterval(Double(day) * 86400 + hour * 3600)
    }

    private func makeStore(weight: Double = 100, days: Int16 = 3, minutes: Double = 0,
                           flagged: Bool = false) -> (NSManagedObjectContext, UserProfile, TrainingProfile) {
        let ctx = Persistence(inMemory: true).container.viewContext
        let user = UserProfile(context: ctx)
        user.id = UUID()
        user.sex = "male"
        user.goal = "maintain"
        user.age = 30
        user.weightKg = weight
        user.heightCm = 180
        let profile = TrainingProfile(context: ctx)
        profile.id = UUID()
        profile.daysPerWeek = days
        profile.currentWeeklyMinutes = minutes
        profile.screeningHasFlag = flagged
        profile.screeningAnsweredAt = Date()
        try? ctx.save()
        return (ctx, user, profile)
    }

    func testNoProfileOrAFlaggedScreeningGivesNoPlan() {
        let ctx = Persistence(inMemory: true).container.viewContext
        let user = UserProfile(context: ctx)
        user.weightKg = 80
        user.heightCm = 180
        XCTAssertNil(TrainingService.ensureWeek(user: user, in: ctx))

        let (flaggedCtx, flaggedUser, profile) = makeStore(flagged: true)
        XCTAssertNil(TrainingService.ensureWeek(user: flaggedUser, in: flaggedCtx))
        profile.doctorCleared = true
        XCTAssertNotNil(TrainingService.ensureWeek(user: flaggedUser, in: flaggedCtx))
    }

    func testFirstWeekIsCreatedOnce() throws {
        let (ctx, user, _) = makeStore()
        let week = try XCTUnwrap(TrainingService.ensureWeek(user: user, in: ctx))
        XCTAssertEqual(week.weekStart, thisMonday)
        XCTAssertEqual(week.decision, "start")
        XCTAssertEqual(week.phase, "transition")
        XCTAssertEqual(week.targetMinutes, 75)
        XCTAssertEqual(week.strengthSets, 1)
        let planned = TrainingService.plannedSessions(weekStart: thisMonday, in: ctx)
        XCTAssertEqual(planned.map(\.dayIndex), [0, 0, 2, 2, 5])
        XCTAssertEqual(planned.filter { $0.kind == "strength" }.count, 2)

        XCTAssertEqual(TrainingService.ensureWeek(user: user, in: ctx)?.objectID, week.objectID)
        XCTAssertEqual(try ctx.fetch(TrainingWeek.fetchRequest()).count, 1)
        XCTAssertEqual(try ctx.fetch(PlannedSession.fetchRequest()).count, 5)
    }

    func testVeryHighBodyMassIndexGetsWalkingOnlyUntilCleared() throws {
        let (ctx, user, _) = makeStore(weight: 120)
        _ = try XCTUnwrap(TrainingService.ensureWeek(user: user, in: ctx))
        XCTAssertTrue(TrainingService.plannedSessions(weekStart: thisMonday, in: ctx).allSatisfy { $0.kind != "strength" })
    }

    func testNextWeekProgressesFromWhatWasDone() throws {
        let (ctx, user, _) = makeStore()
        TrainingService.ensureWeek(user: user, now: at(lastMonday, day: 0), in: ctx)
        for day in [0, 2, 5] {
            TrainingService.logAerobic(modality: .walk, durationMin: 25, rpe: 3, at: at(lastMonday, day: day), in: ctx)
        }
        let week = try XCTUnwrap(TrainingService.ensureWeek(user: user, now: at(thisMonday, day: 0), in: ctx))
        XCTAssertEqual(week.decision, "progress")
        XCTAssertEqual(week.basisMinutes, 75)
        XCTAssertEqual(week.targetMinutes, 90)
        XCTAssertEqual(week.weekInBlock, 2)
        XCTAssertEqual(TrainingService.weekNumber(of: week, in: ctx), 2)
    }

    func testAnEmptyWeekIsRepeated() throws {
        let (ctx, user, _) = makeStore()
        TrainingService.ensureWeek(user: user, now: at(lastMonday, day: 0), in: ctx)
        let week = try XCTUnwrap(TrainingService.ensureWeek(user: user, now: at(thisMonday, day: 0), in: ctx))
        XCTAssertEqual(week.decision, "repeatWeek")
        XCTAssertEqual(week.targetMinutes, 75)
    }

    func testAerobicLogIsBoundedAndLinked() throws {
        let (ctx, user, _) = makeStore()
        TrainingService.ensureWeek(user: user, in: ctx)
        let planned = try XCTUnwrap(TrainingService.plannedSessions(weekStart: thisMonday, in: ctx).first { $0.kind == "easy" })
        let session = TrainingService.logAerobic(modality: .incline, durationMin: 9000, rpe: 14, elevationGainM: -5,
                                                 avgHR: 500, note: String(repeating: "x", count: 900),
                                                 plannedSessionID: planned.id, at: at(thisMonday, day: 0), in: ctx)
        XCTAssertEqual(session.durationMin, 600)
        XCTAssertEqual(session.rpe, 10)
        XCTAssertEqual(session.elevationGainM, 0)
        XCTAssertEqual(session.avgHR, 0)
        XCTAssertEqual(session.note?.count, 500)
        XCTAssertEqual(session.modality, "incline")
        XCTAssertEqual(session.kind, "aerobic")
        XCTAssertEqual(session.source, "manual")
        XCTAssertEqual(session.dayColor, "unknown")
        XCTAssertEqual(session.plannedSessionID, planned.id)
        XCTAssertEqual(TrainingService.plannedAerobicMinutes(on: at(thisMonday, day: 0), in: ctx), 25)
        XCTAssertEqual(TrainingService.plannedAerobicMinutes(on: at(thisMonday, day: 1), in: ctx), 0)
    }

    func testStrengthLogKeepsSetsAndDeletingRemovesThem() throws {
        let (ctx, _, _) = makeStore()
        let sets = [StrengthSetInput(exercise: "step-up", loadKg: 0, reps: 12, rir: 3),
                    StrengthSetInput(exercise: "step-up", loadKg: 0, reps: 11, rir: 3),
                    StrengthSetInput(exercise: "seated-row", loadKg: 9000, reps: 10, rir: 30),
                    StrengthSetInput(exercise: "seated-row", loadKg: 20, reps: 0, rir: 2)]
        let session = TrainingService.logStrength(sets: sets, durationMin: 25, rpe: 5, at: at(thisMonday, day: 0), in: ctx)
        XCTAssertEqual(session.kind, "strength")
        let stored = try ctx.fetch(StrengthSet.fetchRequest())
        XCTAssertEqual(stored.count, 3)
        XCTAssertEqual(TrainingService.lastSets(exercise: "step-up", in: ctx),
                       [SetResult(loadKg: 0, reps: 12, rir: 3), SetResult(loadKg: 0, reps: 11, rir: 3)])
        XCTAssertEqual(TrainingService.lastSets(exercise: "seated-row", in: ctx), [SetResult(loadKg: 500, reps: 10, rir: 10)])
        XCTAssertTrue(TrainingService.lastSets(exercise: "dead-bug", in: ctx).isEmpty)

        TrainingService.delete(session, in: ctx)
        XCTAssertTrue(try ctx.fetch(StrengthSet.fetchRequest()).isEmpty)
        XCTAssertTrue(try ctx.fetch(TrainingSession.fetchRequest()).isEmpty)
    }

    func testDayWithoutACheckInPlansLikeANormalDay() {
        let normal = SessionAdjuster.adjust(kind: .long, targetMinutes: 90, strengthSets: 0, color: .green, weekBadDays: 0)
        let unknown = SessionAdjuster.adjust(kind: .long, targetMinutes: 90, strengthSets: 0, color: .unknown, weekBadDays: 0)
        XCTAssertEqual(unknown.targetMinutes, normal.targetMinutes)
        XCTAssertEqual(unknown.isRest, normal.isRest)
        XCTAssertEqual(DayColor.unknown.label, "No check-in")
    }

    func testDayColourComesFromTheCheckIn() {
        let (ctx, _, _) = makeStore()
        XCTAssertEqual(TrainingService.color(on: Date(), in: ctx), .unknown)
        XCTAssertEqual(TrainingService.badDays(from: thisMonday, to: thisMonday.addingTimeInterval(7 * 86400), in: ctx), 0)
        var answers = CheckInAnswers(wakeTime: Date())
        answers.energy = 4
        answers.quality = 4
        answers.soreness = 2
        answers.stress = 2
        answers.sleepHours = 5.5
        DailyCheckIn.create(answers, bedtime: nil, in: ctx)
        XCTAssertEqual(TrainingService.color(on: Date(), in: ctx), .yellow)
        for checkIn in (try? ctx.fetch(DailyCheckIn.fetchRequest())) ?? [] { checkIn.isSick = true }
        XCTAssertEqual(TrainingService.color(on: Date(), in: ctx), .red)
        XCTAssertEqual(TrainingService.badDays(from: thisMonday, to: thisMonday.addingTimeInterval(7 * 86400), in: ctx), 1)
    }

    func testWeekLoadSumsTheSessionsOfTheWeek() {
        let (ctx, _, _) = makeStore()
        TrainingService.logAerobic(modality: .walk, durationMin: 60, rpe: 3, at: at(lastMonday, day: 1), in: ctx)
        TrainingService.logAerobic(modality: .walk, durationMin: 80, rpe: 3, elevationGainM: 150, at: at(thisMonday, day: 0), in: ctx)
        let load = TrainingService.weekLoad(now: at(thisMonday, day: 0, hour: 20), in: ctx)
        XCTAssertEqual(load.aerobicMinutes, 80)
        XCTAssertEqual(load.elevationM, 150)
        XCTAssertEqual(load.warnings, [.weeklyJump(percent: 33), .sessionPeak(minutes: 80)])
    }

    func testChangingTheDaysRebuildsTheWeekAndKeepsTheLog() throws {
        let (ctx, user, profile) = makeStore(minutes: 200)
        TrainingService.ensureWeek(user: user, in: ctx)
        TrainingService.logAerobic(modality: .walk, durationMin: 30, rpe: 3, at: at(thisMonday, day: 0), in: ctx)
        profile.daysPerWeek = 5
        TrainingService.regenerateWeek(user: user, in: ctx)
        let planned = TrainingService.plannedSessions(weekStart: thisMonday, in: ctx)
        XCTAssertEqual(planned.filter { $0.kind != "strength" }.count, 5)
        XCTAssertEqual(try ctx.fetch(TrainingWeek.fetchRequest()).count, 1)
        XCTAssertEqual(try ctx.fetch(TrainingSession.fetchRequest()).count, 1)
    }

    func testLongAndHardSessionsOfTheDayAreDetected() {
        let (ctx, _, _) = makeStore()
        XCTAssertFalse(TrainingService.hasLongSession(on: Date(), in: ctx))
        XCTAssertFalse(TrainingService.hasHardSession(on: Date(), in: ctx))

        TrainingService.logAerobic(modality: .walk, durationMin: 120, rpe: 4, in: ctx)
        XCTAssertFalse(TrainingService.hasLongSession(on: Date(), in: ctx))
        XCTAssertFalse(TrainingService.hasHardSession(on: Date(), in: ctx))

        TrainingService.logAerobic(modality: .hike, durationMin: 121, rpe: 5, in: ctx)
        XCTAssertTrue(TrainingService.hasLongSession(on: Date(), in: ctx))
        XCTAssertTrue(TrainingService.hasHardSession(on: Date(), in: ctx))

        let yesterday = Date().addingTimeInterval(-86400)
        XCTAssertFalse(TrainingService.hasLongSession(on: yesterday, in: ctx))
        XCTAssertFalse(TrainingService.hasHardSession(on: yesterday, in: ctx))
    }

    func testAPlannedLongSessionCountsBeforeItIsLogged() {
        let (ctx, _, _) = makeStore()
        let planned = PlannedSession(context: ctx)
        planned.id = UUID()
        planned.weekStart = TargetService.weekStart(for: Date())
        planned.dayIndex = Int16(TrainingService.dayIndex(of: Date()))
        planned.kind = "long"
        planned.modality = "hike"
        planned.targetMinutes = 150
        try? ctx.save()
        XCTAssertTrue(TrainingService.hasLongSession(on: Date(), in: ctx))
        XCTAssertFalse(TrainingService.hasHardSession(on: Date(), in: ctx))
    }

    func testTheColourComesFromTheCheckInAndNotFromTheScore() {
        let (ctx, _, _) = makeStore()
        var answers = CheckInAnswers(wakeTime: Date())
        answers.energy = 2
        answers.quality = 4
        answers.soreness = 1
        answers.stress = 1
        answers.sleepHours = 8
        DailyCheckIn.create(answers, bedtime: nil, in: ctx)
        XCTAssertEqual(TrainingService.color(on: Date(), in: ctx), .yellow)
        XCTAssertEqual(TrainingService.state(on: Date(), in: ctx)?.energy, 2)
    }

    func testTheEnergyBaselineSkipsSickDaysAndToday() {
        let (ctx, _, _) = makeStore()
        let today = Calendar.current.startOfDay(for: Date())
        for offset in 1...3 {
            let checkIn = DailyCheckIn(context: ctx)
            checkIn.id = UUID()
            checkIn.date = today.addingTimeInterval(Double(-offset) * 86400)
            checkIn.energyLevel = Int16(offset)
            checkIn.isSick = offset == 2
        }
        let todays = DailyCheckIn(context: ctx)
        todays.id = UUID()
        todays.date = today
        todays.energyLevel = 5
        try? ctx.save()
        XCTAssertEqual(TrainingService.energyBaseline(before: Date(), in: ctx).sorted(), [1, 3])
    }

    func testTheWeekRemembersTheLightWeekChoice() {
        let (ctx, user, _) = makeStore()
        TrainingService.ensureWeek(user: user, now: thisMonday, in: ctx)
        XCTAssertNil(TrainingService.lightWeekChoice(weekStart: thisMonday, in: ctx))
        TrainingService.setLightWeekChoice(.applied, weekStart: thisMonday, in: ctx)
        XCTAssertEqual(TrainingService.lightWeekChoice(weekStart: thisMonday, in: ctx), .applied)
        TrainingService.setLightWeekChoice(.kept, weekStart: thisMonday, in: ctx)
        XCTAssertEqual(TrainingService.lightWeekChoice(weekStart: thisMonday, in: ctx), .kept)
    }

    func testYellowDaysWithASessionAreCounted() {
        let (ctx, _, _) = makeStore()
        let today = Calendar.current.startOfDay(for: Date())
        for offset in 1...3 {
            let checkIn = DailyCheckIn(context: ctx)
            checkIn.id = UUID()
            checkIn.date = today.addingTimeInterval(Double(-offset) * 86400)
            checkIn.energyLevel = 2
            checkIn.sleepHours = 8
            TrainingService.logAerobic(modality: .walk, durationMin: 30, rpe: 3,
                                       at: checkIn.date!.addingTimeInterval(3600), in: ctx)
        }
        try? ctx.save()
        XCTAssertEqual(TrainingService.yellowDaysWithSession(since: today.addingTimeInterval(-7 * 86400), in: ctx), 3)
    }

    private func threeLowDays(in week: Date, ctx: NSManagedObjectContext) {
        for day in [0, 1, 2] {
            let checkIn = DailyCheckIn(context: ctx)
            checkIn.id = UUID()
            checkIn.date = Calendar.current.startOfDay(for: at(week, day: day))
            checkIn.energyLevel = 2
            checkIn.sleepHours = 8
        }
        try? ctx.save()
    }

    func testKeepingThePlanAfterThreeLowDaysLetsTheNextWeekProgress() throws {
        let (ctx, user, _) = makeStore()
        TrainingService.ensureWeek(user: user, now: at(lastMonday, day: 0), in: ctx)
        threeLowDays(in: lastMonday, ctx: ctx)
        TrainingService.setLightWeekChoice(.kept, weekStart: lastMonday, in: ctx)
        for day in [0, 2, 5] {
            TrainingService.logAerobic(modality: .walk, durationMin: 25, rpe: 3, at: at(lastMonday, day: day), in: ctx)
        }
        let week = try XCTUnwrap(TrainingService.ensureWeek(user: user, now: at(thisMonday, day: 0), in: ctx))
        XCTAssertEqual(week.decision, "progress")
    }

    func testMakingItLighterRepeatsTheNextWeek() throws {
        let (ctx, user, _) = makeStore()
        TrainingService.ensureWeek(user: user, now: at(lastMonday, day: 0), in: ctx)
        threeLowDays(in: lastMonday, ctx: ctx)
        TrainingService.setLightWeekChoice(.applied, weekStart: lastMonday, in: ctx)
        for day in [0, 2, 5] {
            TrainingService.logAerobic(modality: .walk, durationMin: 25, rpe: 3, at: at(lastMonday, day: day), in: ctx)
        }
        let week = try XCTUnwrap(TrainingService.ensureWeek(user: user, now: at(thisMonday, day: 0), in: ctx))
        XCTAssertEqual(week.decision, "lowReadiness")
    }

    func testRegeneratingTheWeekKeepsTheLightWeekChoice() {
        let (ctx, user, _) = makeStore()
        TrainingService.ensureWeek(user: user, now: thisMonday, in: ctx)
        TrainingService.setLightWeekChoice(.applied, weekStart: thisMonday, in: ctx)
        TrainingService.regenerateWeek(user: user, now: thisMonday, in: ctx)
        XCTAssertEqual(TrainingService.lightWeekChoice(weekStart: thisMonday, in: ctx), .applied)
    }

    func testTheLightWeekQuestionNeedsAWeekToAnswerFor() {
        let (ctx, user, _) = makeStore()
        XCTAssertFalse(TrainingService.shouldAskLightWeek(weekStart: thisMonday, badDays: 3, in: ctx))
        TrainingService.ensureWeek(user: user, now: thisMonday, in: ctx)
        XCTAssertTrue(TrainingService.shouldAskLightWeek(weekStart: thisMonday, badDays: 3, in: ctx))
        XCTAssertFalse(TrainingService.shouldAskLightWeek(weekStart: thisMonday, badDays: 2, in: ctx))
        TrainingService.setLightWeekChoice(.kept, weekStart: thisMonday, in: ctx)
        XCTAssertFalse(TrainingService.shouldAskLightWeek(weekStart: thisMonday, badDays: 3, in: ctx))
    }

    func testALighterStrengthSessionDoesNotSetTheNextProgression() {
        let (ctx, _, _) = makeStore()
        let today = Calendar.current.startOfDay(for: Date())
        let older = today.addingTimeInterval(-2 * 86400)
        _ = TrainingService.logStrength(sets: [StrengthSetInput(exercise: "goblet-squat", loadKg: 20, reps: 10, rir: 2)],
                                        durationMin: 25, rpe: 5, at: older.addingTimeInterval(9 * 3600), in: ctx)
        let checkIn = DailyCheckIn(context: ctx)
        checkIn.id = UUID()
        checkIn.date = today
        checkIn.energyLevel = 2
        checkIn.suggestionChoice = SuggestionChoice.applied.rawValue
        _ = TrainingService.logStrength(sets: [StrengthSetInput(exercise: "goblet-squat", loadKg: 20, reps: 15, rir: 4)],
                                        durationMin: 25, rpe: 4, at: today.addingTimeInterval(9 * 3600), in: ctx)
        try? ctx.save()
        XCTAssertEqual(TrainingService.lastSets(exercise: "goblet-squat", in: ctx).map(\.reps), [10])
    }

    func testYellowDaysAfterTheTwelveWeekWindowAreNotCounted() {
        let (ctx, _, _) = makeStore()
        let today = Calendar.current.startOfDay(for: Date())
        let checkIn = DailyCheckIn(context: ctx)
        checkIn.id = UUID()
        checkIn.date = today.addingTimeInterval(-86400)
        checkIn.energyLevel = 2
        checkIn.sleepHours = 8
        TrainingService.logAerobic(modality: .walk, durationMin: 30, rpe: 3,
                                   at: checkIn.date!.addingTimeInterval(3600), in: ctx)
        try? ctx.save()
        XCTAssertEqual(TrainingService.yellowDaysWithSession(since: today.addingTimeInterval(-30 * 86400), in: ctx), 1)
        XCTAssertEqual(TrainingService.yellowDaysWithSession(since: today.addingTimeInterval(-100 * 86400), in: ctx), 0)
    }

    func testTheModeIsOnlyWorkedOutOnYellowDays() throws {
        let (ctx, user, _) = makeStore()
        TrainingService.ensureWeek(user: user, now: thisMonday, in: ctx)
        let planned = try XCTUnwrap(TrainingService.plannedSessions(weekStart: thisMonday, in: ctx).first)
        user.yellowMode = YellowMode.off.rawValue
        let green = TrainingService.sessionPlan(planned, profile: user, color: .green, badDays: 0, now: Date(), in: ctx)
        XCTAssertEqual(green.applied.targetMinutes, planned.targetMinutes)
        XCTAssertNil(green.suggestion)
    }

    private func addCheckIn(daysAgo: Int, energy: Int, soreness: Int = 2, stress: Int = 2, hours: Double = 7.5,
                            sick: Bool = false, dayEnergy: Int = 0, in ctx: NSManagedObjectContext) {
        let today = Calendar.current.startOfDay(for: Date())
        let checkIn = DailyCheckIn(context: ctx)
        checkIn.id = UUID()
        checkIn.date = today.addingTimeInterval(Double(-daysAgo) * 86400)
        checkIn.energyLevel = Int16(energy)
        checkIn.soreness = Int16(soreness)
        checkIn.stress = Int16(stress)
        checkIn.sleepHours = hours
        checkIn.sleepQuality = 3
        checkIn.isSick = sick
        checkIn.dayEnergy = Int16(dayEnergy)
        checkIn.bedtime = checkIn.date!.addingTimeInterval(-30 * 60)
    }

    func testTheStateBoardUsesTheTwentyEightDaysBeforeToday() {
        let (ctx, user, _) = makeStore()
        for daysAgo in 1...20 { addCheckIn(daysAgo: daysAgo, energy: 4, in: ctx) }
        addCheckIn(daysAgo: 30, energy: 1, in: ctx)
        addCheckIn(daysAgo: 0, energy: 3, hours: 5.5, in: ctx)
        try? ctx.save()
        let board = TrainingService.stateBoard(on: Date(), profile: user, in: ctx)
        XCTAssertEqual(board?.baselineDays, 20)
        XCTAssertEqual(board?.rows.first?.usual, 4)
        XCTAssertEqual(board?.rows.first?.band, .below)
        XCTAssertEqual(board?.sleep?.hours, 5.5)
        XCTAssertNil(TrainingService.stateBoard(on: Date().addingTimeInterval(86400), profile: user, in: ctx))
    }

    func testTheSleepSummaryReadsTheLastSevenNights() {
        let (ctx, user, _) = makeStore()
        for daysAgo in 0...9 { addCheckIn(daysAgo: daysAgo, energy: 4, hours: daysAgo < 7 ? 8 : 5, in: ctx) }
        try? ctx.save()
        let summary = TrainingService.sleepSummary(now: Date(), profile: user, in: ctx)
        XCTAssertEqual(summary.averageText, "7-night average 8.0 h")
        XCTAssertEqual(summary.enoughNightsText, "7 of 7 nights with 7 h or more")
        XCTAssertNotNil(summary.regularity)
    }
}
