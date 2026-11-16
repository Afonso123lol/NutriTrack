import CoreData

struct StrengthSetInput {
    let exercise: String
    let loadKg: Double
    let reps: Int
    let rir: Int
}

enum TrainingService {
    static let historyWeeks = 8
    static let day: TimeInterval = 86400

    static func shifted(_ date: Date, days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: date) ?? date.addingTimeInterval(Double(days) * day)
    }
    static let longSessionMinutes = 120.0

    static func profile(in ctx: NSManagedObjectContext) -> TrainingProfile? {
        let request = TrainingProfile.fetchRequest()
        request.fetchLimit = 1
        return try? ctx.fetch(request).first
    }

    static func gate(_ profile: TrainingProfile, user: UserProfile) -> ScreeningGate.Status {
        ScreeningGate.status(hasFlag: profile.screeningHasFlag, doctorCleared: profile.doctorCleared,
                             bmi: BodyMetrics.bmi(weightKg: user.weightKg, heightCm: user.heightCm))
    }

    static func week(startingAt start: Date, in ctx: NSManagedObjectContext) -> TrainingWeek? {
        let request = TrainingWeek.fetchRequest()
        request.predicate = NSPredicate(format: "weekStart == %@", start as NSDate)
        request.fetchLimit = 1
        return try? ctx.fetch(request).first
    }

    static func plannedSessions(weekStart: Date, in ctx: NSManagedObjectContext) -> [PlannedSession] {
        let request = PlannedSession.fetchRequest()
        request.predicate = NSPredicate(format: "weekStart == %@", weekStart as NSDate)
        return ((try? ctx.fetch(request)) ?? []).sorted {
            ($0.dayIndex, $0.kind == "strength" ? 1 : 0) < ($1.dayIndex, $1.kind == "strength" ? 1 : 0)
        }
    }

    static func sessions(from start: Date, to end: Date, in ctx: NSManagedObjectContext) -> [TrainingSession] {
        let request = TrainingSession.fetchRequest()
        request.predicate = NSPredicate(format: "startedAt >= %@ AND startedAt < %@", start as NSDate, end as NSDate)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \TrainingSession.startedAt, ascending: true)]
        return (try? ctx.fetch(request)) ?? []
    }

    static func dayIndex(of date: Date) -> Int {
        let start = TargetService.weekStart(for: date)
        return Calendar.current.dateComponents([.day], from: start, to: Calendar.current.startOfDay(for: date)).day ?? 0
    }

    static func weekNumber(of week: TrainingWeek, in ctx: NSManagedObjectContext) -> Int {
        guard let start = week.weekStart else { return 1 }
        let request = TrainingWeek.fetchRequest()
        request.predicate = NSPredicate(format: "weekStart <= %@", start as NSDate)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \TrainingWeek.weekStart, ascending: true)]
        let weeks = (try? ctx.fetch(request)) ?? []
        let restart = weeks.lastIndex { $0.decision == WeekDecision.start.rawValue || $0.decision == WeekDecision.restart.rawValue } ?? 0
        return max(weeks.count - restart, 1)
    }

    @discardableResult
    static func ensureWeek(user: UserProfile, now: Date = Date(), in ctx: NSManagedObjectContext) -> TrainingWeek? {
        guard let profile = profile(in: ctx) else { return nil }
        let status = gate(profile, user: user)
        guard status != .blocked else { return nil }
        let start = TargetService.weekStart(for: now)
        if let existing = week(startingAt: start, in: ctx) { return existing }

        let request = TrainingWeek.fetchRequest()
        request.predicate = NSPredicate(format: "weekStart < %@", start as NSDate)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \TrainingWeek.weekStart, ascending: true)]
        let weeks = (try? ctx.fetch(request)) ?? []
        let restart = weeks.lastIndex { $0.decision == WeekDecision.start.rawValue || $0.decision == WeekDecision.restart.rawValue } ?? 0
        let recentWeeks = Array(weeks.suffix(historyWeeks))
        let history = recentWeeks.enumerated().map { index, week in
            summary(of: week, countsBadDays: index == recentWeeks.count - 1, in: ctx)
        }

        let calendar = Calendar.current
        let latestRequest = TrainingSession.fetchRequest()
        latestRequest.predicate = NSPredicate(format: "startedAt < %@", now as NSDate)
        latestRequest.sortDescriptors = [NSSortDescriptor(keyPath: \TrainingSession.startedAt, ascending: false)]
        latestRequest.fetchLimit = 1
        let gap = (try? ctx.fetch(latestRequest).first)?.startedAt.flatMap {
            calendar.dateComponents([.day], from: calendar.startOfDay(for: $0), to: calendar.startOfDay(for: now)).day
        }
        let recent = (1...4).map { aerobicMinutes(from: start.addingTimeInterval(-Double($0) * 7 * day),
                                                  to: start.addingTimeInterval(-Double($0 - 1) * 7 * day), in: ctx) }
        let longest = sessions(from: now.addingTimeInterval(-30 * day), to: now, in: ctx)
            .filter { $0.kind != "strength" }.map(\.durationMin).max() ?? 0

        let plan = TrainingPlanner.nextWeek(PlannerInput(
            daysPerWeek: Int(profile.daysPerWeek), declaredWeeklyMinutes: profile.currentWeeklyMinutes,
            bmi: BodyMetrics.bmi(weightKg: user.weightKg, heightCm: user.heightCm),
            hasTreadmill: profile.hasTreadmill, hasBike: profile.hasBike, allowsStrength: status == .full,
            history: history, weeksSinceStart: weeks.isEmpty ? 0 : weeks.count - restart,
            daysSinceLastSession: gap, recentDoneMinutes: recent.contains { $0 > 0 } ? recent : [],
            longestSessionLast30Days: longest
        ))

        let week = TrainingWeek(context: ctx)
        week.id = UUID()
        week.weekStart = start
        week.phase = plan.phase.rawValue
        week.blockIndex = Int16(plan.blockIndex)
        week.weekInBlock = Int16(plan.weekInBlock)
        week.isDeload = plan.isDeload
        week.targetMinutes = plan.targetMinutes
        week.basisMinutes = plan.basisMinutes
        week.decision = plan.decision.rawValue
        week.strengthSets = Int16(plan.strengthSets)
        week.generatedAt = now
        for session in plan.sessions {
            let planned = PlannedSession(context: ctx)
            planned.id = UUID()
            planned.weekStart = start
            planned.dayIndex = Int16(session.dayIndex)
            planned.kind = session.kind.rawValue
            planned.modality = session.modality.rawValue
            planned.targetMinutes = session.targetMinutes
            planned.strengthSets = Int16(session.strengthSets)
        }
        try? ctx.save()
        return week
    }

    static func regenerateWeek(user: UserProfile, now: Date = Date(), in ctx: NSManagedObjectContext) {
        let start = TargetService.weekStart(for: now)
        let choice = week(startingAt: start, in: ctx)?.lightWeekChoice
        if let week = week(startingAt: start, in: ctx) { ctx.delete(week) }
        for planned in plannedSessions(weekStart: start, in: ctx) { ctx.delete(planned) }
        try? ctx.save()
        ensureWeek(user: user, now: now, in: ctx)
        if let choice, let week = week(startingAt: start, in: ctx) {
            week.lightWeekChoice = choice
            try? ctx.save()
        }
    }

    static func energyBaseline(before date: Date, in ctx: NSManagedObjectContext) -> [Int] {
        let start = Calendar.current.startOfDay(for: date)
        let request = DailyCheckIn.fetchRequest()
        request.predicate = NSPredicate(format: "date >= %@ AND date < %@ AND isSick == NO AND energyLevel > 0",
                                        start.addingTimeInterval(-28 * day) as NSDate, start as NSDate)
        return ((try? ctx.fetch(request)) ?? []).map { Int($0.energyLevel) }
    }

    static func state(on date: Date, in ctx: NSManagedObjectContext) -> DayState? {
        guard let checkIn = DailyCheckIn.on(date, in: ctx) else { return nil }
        return DayState(energy: Int(checkIn.energyLevel), sleepHours: checkIn.sleepHours,
                        isSick: checkIn.isSick, hasPain: checkIn.hasPain,
                        energyBaseline: energyBaseline(before: date, in: ctx))
    }

    static func color(on date: Date, in ctx: NSManagedObjectContext) -> DayColor {
        state(on: date, in: ctx).map(DayReadiness.color) ?? .unknown
    }

    static func reasons(on date: Date, in ctx: NSManagedObjectContext) -> [DayReason] {
        state(on: date, in: ctx).map(DayReadiness.reasons) ?? []
    }

    static func checkIns(from start: Date, to end: Date, in ctx: NSManagedObjectContext) -> [DailyCheckIn] {
        let request = DailyCheckIn.fetchRequest()
        request.predicate = NSPredicate(format: "date >= %@ AND date < %@", start as NSDate, end as NSDate)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \DailyCheckIn.date, ascending: true)]
        return (try? ctx.fetch(request)) ?? []
    }

    static func stateBoard(on date: Date, profile: UserProfile, in ctx: NSManagedObjectContext) -> DayStateBoard? {
        guard let today = DailyCheckIn.on(date, in: ctx) else { return nil }
        let start = Calendar.current.startOfDay(for: date)
        let history = checkIns(from: shifted(start, days: -DayStateBoard.windowDays), to: start, in: ctx)
        func entry(_ checkIn: DailyCheckIn) -> DayStateBoard.Entry {
            DayStateBoard.Entry(energy: Int(checkIn.energyLevel), soreness: Int(checkIn.soreness),
                                stress: Int(checkIn.stress), isSick: checkIn.isSick, hasPain: checkIn.hasPain)
        }
        return DayStateBoard.make(today: entry(today), history: history.map(entry),
                                  sleepHours: today.sleepHours, sleepNeed: profile.sleepNeed)
    }

    static func sleepSummary(now: Date, profile: UserProfile, in ctx: NSManagedObjectContext) -> SleepSummary {
        let end = shifted(Calendar.current.startOfDay(for: now), days: 1)
        func night(_ checkIn: DailyCheckIn) -> SleepSummary.Night {
            SleepSummary.Night(hours: checkIn.sleepHours, quality: Int(checkIn.sleepQuality),
                               bedtime: checkIn.bedtime, dayEnergy: Int(checkIn.dayEnergy))
        }
        return SleepSummary.make(lastSeven: checkIns(from: shifted(end, days: -7), to: end, in: ctx).map(night),
                                 recent: checkIns(from: shifted(end, days: -90), to: end, in: ctx).map(night))
    }

    static func lightWeekChoice(weekStart: Date, in ctx: NSManagedObjectContext) -> SuggestionChoice? {
        week(startingAt: weekStart, in: ctx)?.lightWeekChoice.flatMap(SuggestionChoice.init(rawValue:))
    }

    static func setLightWeekChoice(_ choice: SuggestionChoice, weekStart: Date, in ctx: NSManagedObjectContext) {
        guard let week = week(startingAt: weekStart, in: ctx) else { return }
        week.lightWeekChoice = choice.rawValue
        try? ctx.save()
    }

    static func shouldAskLightWeek(weekStart: Date, badDays: Int, in ctx: NSManagedObjectContext) -> Bool {
        guard badDays >= TrainingPlanner.badDaysForRepeat, let week = week(startingAt: weekStart, in: ctx) else {
            return false
        }
        return week.lightWeekChoice == nil
    }

    static func yellowMode(profile: UserProfile, now: Date, in ctx: NSManagedObjectContext) -> YellowMode {
        Calibration.mode(stored: profile.yellowMode, startedAt: profile.calibrationStartedAt, now: now,
                         yellowDaysWithSession: yellowDaysWithSession(since: profile.calibrationStartedAt ?? now, in: ctx))
    }

    static func sessionPlan(_ planned: PlannedSession, profile: UserProfile, color: DayColor, badDays: Int,
                            now: Date, in ctx: NSManagedObjectContext) -> DaySessionPlan {
        let weekChoice = lightWeekChoice(weekStart: TargetService.weekStart(for: now), in: ctx)
        return DaySessionPlan.make(kind: SessionKind(rawValue: planned.kind ?? "") ?? .easy,
                                   targetMinutes: planned.targetMinutes, strengthSets: Int(planned.strengthSets),
                                   color: color, weekBadDays: weekChoice == .applied ? badDays : 0,
                                   mode: color == .yellow ? yellowMode(profile: profile, now: now, in: ctx) : .suggest,
                                   choice: DailyCheckIn.on(now, in: ctx)?.suggestionChoiceValue)
    }

    static func yellowDaysWithSession(since date: Date, in ctx: NSManagedObjectContext) -> Int {
        let start = Calendar.current.startOfDay(for: date)
        let end = start.addingTimeInterval(Calibration.maximumWeeks * 7 * day)
        let request = DailyCheckIn.fetchRequest()
        request.predicate = NSPredicate(format: "date >= %@ AND date < %@", start as NSDate, end as NSDate)
        return ((try? ctx.fetch(request)) ?? []).filter { checkIn in
            guard let dayStart = checkIn.date, color(on: dayStart, in: ctx) == .yellow else { return false }
            return !sessions(from: dayStart, to: dayStart.addingTimeInterval(day), in: ctx).isEmpty
        }.count
    }

    static func calibrationDays(since start: Date?, in ctx: NSManagedObjectContext) -> [CalibrationReport.Day] {
        guard let start else { return [] }
        let request = DailyCheckIn.fetchRequest()
        request.predicate = NSPredicate(format: "date >= %@", Calendar.current.startOfDay(for: start) as NSDate)
        return ((try? ctx.fetch(request)) ?? []).compactMap { checkIn in
            guard let dayStart = checkIn.date else { return nil }
            let logged = sessions(from: dayStart, to: dayStart.addingTimeInterval(day), in: ctx)
                .filter { $0.kind != SessionKind.strength.rawValue }
            let planned = plannedAerobicMinutes(on: dayStart, in: ctx)
            return CalibrationReport.Day(
                color: color(on: dayStart, in: ctx),
                rpe: logged.map { Int($0.rpe) }.max(),
                doneMinutes: logged.isEmpty ? nil : logged.reduce(0) { $0 + $1.durationMin },
                plannedMinutes: planned > 0 ? planned : nil,
                dayEnergy: checkIn.dayEnergy > 0 ? Int(checkIn.dayEnergy) : nil,
                choice: checkIn.suggestionChoiceValue)
        }
    }

    static func badDays(from start: Date, to end: Date, in ctx: NSManagedObjectContext) -> Int {
        var count = 0
        var cursor = start
        while cursor < end {
            if color(on: cursor, in: ctx).isBad { count += 1 }
            cursor = Calendar.current.date(byAdding: .day, value: 1, to: cursor) ?? end
        }
        return count
    }

    static func plannedAerobicMinutes(on date: Date, in ctx: NSManagedObjectContext) -> Double {
        let index = Int16(dayIndex(of: date))
        return plannedSessions(weekStart: TargetService.weekStart(for: date), in: ctx)
            .filter { $0.dayIndex == index && $0.kind != "strength" }
            .reduce(0) { $0 + $1.targetMinutes }
    }

    static func hasLongSession(on date: Date, in ctx: NSManagedObjectContext) -> Bool {
        let start = Calendar.current.startOfDay(for: date)
        let index = Int16(dayIndex(of: date))
        let isLogged = sessions(from: start, to: start.addingTimeInterval(day), in: ctx)
            .contains { $0.durationMin > longSessionMinutes }
        let isPlanned = plannedSessions(weekStart: TargetService.weekStart(for: date), in: ctx)
            .contains { $0.dayIndex == index && $0.targetMinutes > longSessionMinutes }
        return isLogged || isPlanned
    }

    static func hasHardSession(on date: Date, in ctx: NSManagedObjectContext) -> Bool {
        let start = Calendar.current.startOfDay(for: date)
        return sessions(from: start, to: start.addingTimeInterval(day), in: ctx)
            .contains { Int($0.rpe) >= TargetPlanner.hardEffortRPE }
    }

    @discardableResult
    static func logAerobic(modality: Modality, durationMin: Double, rpe: Int, elevationGainM: Double = 0,
                           distanceKm: Double = 0, avgHR: Int = 0, packKg: Double = 0, note: String? = nil,
                           plannedSessionID: UUID? = nil, at date: Date = Date(),
                           in ctx: NSManagedObjectContext) -> TrainingSession {
        let session = makeSession(kind: "aerobic", modality: modality, durationMin: durationMin, rpe: rpe,
                                  plannedSessionID: plannedSessionID, at: date, in: ctx)
        session.elevationGainM = bounded(elevationGainM, 0...9000)
        session.distanceKm = bounded(distanceKm, 0...300)
        session.avgHR = (40...230).contains(avgHR) ? Int16(avgHR) : 0
        session.packKg = bounded(packKg, 0...60)
        let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        session.note = trimmed.isEmpty ? nil : String(trimmed.prefix(500))
        try? ctx.save()
        return session
    }

    @discardableResult
    static func logStrength(sets: [StrengthSetInput], durationMin: Double, rpe: Int, plannedSessionID: UUID? = nil,
                            at date: Date = Date(), in ctx: NSManagedObjectContext) -> TrainingSession {
        let session = makeSession(kind: "strength", modality: .strength, durationMin: durationMin, rpe: rpe,
                                  plannedSessionID: plannedSessionID, at: date, in: ctx)
        var indexes: [String: Int16] = [:]
        for input in sets where input.reps > 0 {
            let set = StrengthSet(context: ctx)
            set.id = UUID()
            set.sessionID = session.id
            set.exercise = input.exercise
            set.setIndex = indexes[input.exercise, default: 0]
            indexes[input.exercise, default: 0] += 1
            set.loadKg = bounded(input.loadKg, 0...500)
            set.reps = Int16(min(input.reps, 100))
            set.rir = Int16(min(max(input.rir, 0), 10))
            set.performedAt = date
        }
        try? ctx.save()
        return session
    }

    static func delete(_ session: TrainingSession, in ctx: NSManagedObjectContext) {
        if let id = session.id {
            let request = StrengthSet.fetchRequest()
            request.predicate = NSPredicate(format: "sessionID == %@", id as CVarArg)
            for set in (try? ctx.fetch(request)) ?? [] { ctx.delete(set) }
        }
        ctx.delete(session)
        try? ctx.save()
    }

    static func lastSets(exercise: String, in ctx: NSManagedObjectContext) -> [SetResult] {
        let latest = StrengthSet.fetchRequest()
        latest.predicate = NSPredicate(format: "exercise == %@", exercise)
        latest.sortDescriptors = [NSSortDescriptor(keyPath: \StrengthSet.performedAt, ascending: false)]
        latest.fetchLimit = 60
        let counting = ((try? ctx.fetch(latest)) ?? []).first { set in
            guard let performedAt = set.performedAt else { return true }
            return DailyCheckIn.on(performedAt, in: ctx)?.suggestionChoiceValue != .applied
        }
        guard let sessionID = counting?.sessionID else { return [] }
        let request = StrengthSet.fetchRequest()
        request.predicate = NSPredicate(format: "exercise == %@ AND sessionID == %@", exercise, sessionID as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \StrengthSet.setIndex, ascending: true)]
        return ((try? ctx.fetch(request)) ?? []).map { SetResult(loadKg: $0.loadKg, reps: Int($0.reps), rir: Int($0.rir)) }
    }

    static func weekLoad(now: Date = Date(), in ctx: NSManagedObjectContext) -> WeekLoad {
        let start = TargetService.weekStart(for: now)
        let week = sessions(from: start, to: start.addingTimeInterval(7 * day), in: ctx).map {
            LoggedSession(isStrength: $0.kind == "strength", durationMin: $0.durationMin, rpe: Int($0.rpe),
                          elevationGainM: $0.elevationGainM)
        }
        let previous = aerobicMinutes(from: start.addingTimeInterval(-7 * day), to: start, in: ctx)
        let earlier = aerobicMinutes(from: start.addingTimeInterval(-14 * day), to: start.addingTimeInterval(-7 * day), in: ctx)
        let longest = sessions(from: start.addingTimeInterval(-30 * day), to: start, in: ctx)
            .filter { $0.kind != "strength" }.map(\.durationMin).max() ?? 0
        return TrainingLoad.summarize(week: week, previousWeekMinutes: previous, twoWeeksAgoMinutes: earlier,
                                      longestBefore: longest)
    }

    static func aerobicMinutes(from start: Date, to end: Date, in ctx: NSManagedObjectContext) -> Double {
        sessions(from: start, to: end, in: ctx).filter { $0.kind != "strength" }.reduce(0) { $0 + $1.durationMin }
    }

    private static func summary(of week: TrainingWeek, countsBadDays: Bool, in ctx: NSManagedObjectContext) -> WeekSummary {
        let start = week.weekStart ?? Date()
        let end = start.addingTimeInterval(7 * day)
        return WeekSummary(plannedMinutes: week.targetMinutes,
                           doneMinutes: aerobicMinutes(from: start, to: end, in: ctx),
                           isDeload: week.isDeload,
                           badDays: countsBadDays && week.lightWeekChoice == SuggestionChoice.applied.rawValue
                               ? badDays(from: start, to: end, in: ctx) : 0,
                           blockIndex: Int(week.blockIndex), weekInBlock: Int(week.weekInBlock))
    }

    private static func makeSession(kind: String, modality: Modality, durationMin: Double, rpe: Int,
                                    plannedSessionID: UUID?, at date: Date, in ctx: NSManagedObjectContext) -> TrainingSession {
        let session = TrainingSession(context: ctx)
        session.id = UUID()
        session.startedAt = date
        session.kind = kind
        session.modality = modality.rawValue
        session.durationMin = bounded(durationMin, 1...600)
        session.rpe = Int16(min(max(rpe, 0), 10))
        session.plannedSessionID = plannedSessionID
        session.dayColor = color(on: date, in: ctx).rawValue
        session.source = "manual"
        return session
    }

    private static func bounded(_ value: Double, _ range: ClosedRange<Double>) -> Double {
        value.isFinite ? min(max(value, range.lowerBound), range.upperBound) : range.lowerBound
    }
}
