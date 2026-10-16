import CoreData

struct TodayScores {
    let sleep: HealthScore?
    let diet: HealthScore?
    let readiness: HealthScore?
}

enum EvaluationService {
    static let autoCloseWindowDays = 14

    static func todayEvaluation(in ctx: NSManagedObjectContext) -> DailyEvaluation? {
        evaluation(for: Date(), in: ctx)
    }

    static func evaluation(for day: Date, in ctx: NSManagedObjectContext) -> DailyEvaluation? {
        let request = DailyEvaluation.fetchRequest()
        request.predicate = dayPredicate(day, key: "date")
        request.fetchLimit = 1
        return try? ctx.fetch(request).first
    }

    static func saveCoachText(_ text: String, day: Date, in ctx: NSManagedObjectContext) {
        let evaluation = evaluationCreatingIfNeeded(for: day, in: ctx)
        evaluation.coachText = text
        evaluation.coachGeneratedAt = Date()
        try? ctx.save()
    }

    static func applyScoreTexts(_ texts: ScoreEvaluationTexts, day: Date, in ctx: NSManagedObjectContext) {
        let evaluation = evaluationCreatingIfNeeded(for: day, in: ctx)
        evaluation.sleepText = texts.sleepComment
        evaluation.readinessText = texts.readinessComment
        try? ctx.save()
    }

    static func saveDietText(_ text: String, day: Date, in ctx: NSManagedObjectContext) {
        let evaluation = evaluationCreatingIfNeeded(for: day, in: ctx)
        evaluation.dietText = text
        try? ctx.save()
    }

    static func historyPredicate(since start: Date) -> NSPredicate {
        NSPredicate(format: "date >= %@ AND generatedAt != nil", start as NSDate)
    }

    static func dietHistoryPredicate(since start: Date) -> NSPredicate {
        NSPredicate(format: "date >= %@ AND closedAt != nil AND isLogComplete == YES", start as NSDate)
    }

    static func completeDayIntakes(now: Date = Date(), in ctx: NSManagedObjectContext) -> [DayNutrients] {
        let today = Calendar.current.startOfDay(for: now)
        guard let start = Calendar.current.date(byAdding: .day, value: 1 - MicronutrientBoard.weekDays, to: today) else {
            return []
        }
        let request = DailyEvaluation.fetchRequest()
        request.predicate = dietHistoryPredicate(since: start)
        let days = ((try? ctx.fetch(request)) ?? []).compactMap(\.date)
        return days.map { day in
            let foodRequest = FoodEntry.fetchRequest()
            foodRequest.predicate = dayPredicate(day, key: "timestamp")
            let supplementRequest = SupplementLog.fetchRequest()
            supplementRequest.predicate = dayPredicate(day, key: "timestamp")
            let food = (try? ctx.fetch(foodRequest)) ?? []
            let supplements = (try? ctx.fetch(supplementRequest)) ?? []
            return DayNutrients(food: NutritionAnalysis.sum(food.map(\.analysis)),
                             supplements: NutritionAnalysis.sum(supplements.compactMap(\.snapshotNutrients)))
        }
    }

    static func dietScore(for day: Date, profile: UserProfile, isClosed: Bool,
                          in ctx: NSManagedObjectContext) -> HealthScore? {
        let targets = profile.macroTargets
        guard let inputs = dietInputs(for: day, limits: targets.limits, in: ctx) else { return nil }
        return HealthScores.dietScore(
            calories: inputs.intake.calories, proteinG: inputs.intake.proteinG, fiberG: inputs.intake.fiberG,
            saturatedFatG: inputs.intake.saturatedFatG,
            sodiumMg: inputs.intake.sodiumMg, microRatios: inputs.microRatios,
            targets: targets, limits: targets.limits, isClosed: isClosed
        )
    }

    static func computeTodayScores(profile: UserProfile, in ctx: NSManagedObjectContext) -> TodayScores {
        let today = Date()
        let isClosed = evaluation(for: today, in: ctx)?.closedAt != nil
        let diet = dietScore(for: today, profile: profile, isClosed: isClosed, in: ctx)
        guard let checkIn = fetchTodayCheckIn(in: ctx) else {
            return TodayScores(sleep: nil, diet: diet, readiness: nil)
        }
        let recent = fetchRecentCheckIns(in: ctx)
        let sleep = HealthScores.sleepScore(
            hours: checkIn.sleepHours, quality: Int(checkIn.sleepQuality),
            bedtimes: recent.compactMap(\.bedtime)
        )
        let readiness = HealthScores.readinessScore(
            todayEnergy: Int(checkIn.energyLevel), lastNightSleep: sleep,
            last7SleepHours: recent.map(\.sleepHours)
        )
        return TodayScores(sleep: sleep, diet: diet, readiness: readiness)
    }

    static func ensureTodayEvaluation(profile: UserProfile, in ctx: NSManagedObjectContext, force: Bool = false) {
        let today = Calendar.current.startOfDay(for: Date())
        guard !ModelJobStore.shared.isPending(.scoreEvaluation(day: today)) else { return }

        if !force, let existing = todayEvaluation(in: ctx),
           existing.sleepText != nil, existing.readinessText != nil {
            return
        }

        guard let checkIn = fetchTodayCheckIn(in: ctx) else { return }
        let scores = computeTodayScores(profile: profile, in: ctx)
        guard let sleep = scores.sleep, let readiness = scores.readiness else { return }

        let recentSleep = fetchRecentCheckIns(in: ctx)
            .map { String(format: "%.1fh", $0.sleepHours) }
            .joined(separator: ", ")
        let summary = """
        Check-in: energy \(checkIn.energyLevel)/5, slept \(String(format: "%.1f", checkIn.sleepHours))h, sleep quality \(checkIn.sleepQuality)/5
        Sleep in the last 7 days, oldest first: \(recentSleep)
        """

        upsert(sleep: sleep, readiness: readiness, in: ctx)
        do {
            let body = try GeminiService.scoreEvaluationRequestBody(sleep: sleep, readiness: readiness,
                                                                    daySummaryText: summary)
            try BackgroundModelClient.shared.enqueue(.scoreEvaluation(day: today), body: body)
        } catch {
            print("EvaluationService enqueue failed: \(error.localizedDescription)")
        }
    }

    static func upsert(sleep: HealthScore, readiness: HealthScore, in ctx: NSManagedObjectContext) {
        let evaluation = evaluationCreatingIfNeeded(for: Date(), in: ctx)
        evaluation.sleepScore = Int16(sleep.value)
        evaluation.readinessScore = Int16(readiness.value)
        evaluation.generatedAt = Date()
        try? ctx.save()
    }

    @discardableResult
    static func closeDay(_ day: Date, profile: UserProfile, isLogComplete: Bool, now: Date = Date(),
                         in ctx: NSManagedObjectContext) -> Bool {
        guard let score = dietScore(for: day, profile: profile, isClosed: true, in: ctx) else { return false }
        let evaluation = evaluationCreatingIfNeeded(for: day, in: ctx)
        evaluation.dietScore = Int16(score.value)
        evaluation.closedAt = now
        evaluation.isLogComplete = isLogComplete
        try? ctx.save()
        return true
    }

    static func autoCloseMissedDays(profile: UserProfile, now: Date = Date(),
                                    in ctx: NSManagedObjectContext) -> [Date] {
        let today = Calendar.current.startOfDay(for: now)
        var closed: [Date] = []
        for offset in 1...autoCloseWindowDays {
            guard let day = Calendar.current.date(byAdding: .day, value: -offset, to: today),
                  evaluation(for: day, in: ctx)?.closedAt == nil else { continue }
            if closeDay(day, profile: profile, isLogComplete: false, now: now, in: ctx) { closed.append(day) }
        }
        return closed
    }

    static func closeMissedDaysAndRequestReview(now: Date = Date(), in ctx: NSManagedObjectContext) {
        guard let profile = fetchProfile(in: ctx) else { return }
        let closed = autoCloseMissedDays(profile: profile, now: now, in: ctx)
        let today = Calendar.current.startOfDay(for: now)
        guard let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today),
              closed.contains(yesterday) else { return }
        requestDietCommentary(day: yesterday, profile: profile, in: ctx)
    }

    static func refreshClosedDay(containing date: Date, in ctx: NSManagedObjectContext) {
        guard let evaluation = evaluation(for: date, in: ctx), evaluation.closedAt != nil,
              let profile = fetchProfile(in: ctx) else { return }
        if let score = dietScore(for: date, profile: profile, isClosed: true, in: ctx) {
            evaluation.dietScore = Int16(score.value)
        } else {
            evaluation.dietScore = 0
            evaluation.closedAt = nil
            evaluation.isLogComplete = false
        }
        try? ctx.save()
    }

    static func requestDietCommentary(day: Date, profile: UserProfile, in ctx: NSManagedObjectContext) {
        let start = Calendar.current.startOfDay(for: day)
        guard !ModelJobStore.shared.isPending(.dietEvaluation(day: start)),
              let score = dietScore(for: day, profile: profile, isClosed: true, in: ctx),
              let summary = dietSummaryText(for: day, profile: profile, in: ctx) else { return }
        do {
            let body = try GeminiService.dietEvaluationRequestBody(diet: score, daySummaryText: summary)
            try BackgroundModelClient.shared.enqueue(.dietEvaluation(day: start), body: body)
        } catch {
            print("EvaluationService enqueue failed: \(error.localizedDescription)")
        }
    }

    static func dietSummaryText(for day: Date, profile: UserProfile, in ctx: NSManagedObjectContext) -> String? {
        let targets = profile.macroTargets
        guard let inputs = dietInputs(for: day, limits: targets.limits, in: ctx) else { return nil }
        let intake = inputs.intake
        let met = inputs.microRatios.filter { $0 >= 1 }.count
        return """
        Calories: \(Int(intake.calories)) / \(Int(targets.calories)) kcal target
        Protein: \(Int(intake.proteinG))g / \(Int(targets.proteinG))g target
        Fiber: \(Int(intake.fiberG))g, Saturated fat: \(Int(intake.saturatedFatG))g, Sugar: \(Int(intake.sugarG))g, Sodium: \(Int(intake.sodiumMg))mg, Alcohol: \(Int(intake.alcoholG ?? 0))g
        Micronutrients at or above the minimum: \(met)/\(inputs.microRatios.count)
        Meals: \(inputs.mealNames)
        Supplements: \(inputs.supplementNames.isEmpty ? "none" : inputs.supplementNames)
        """
    }

    private struct DietInputs {
        let intake: NutritionAnalysis
        let microRatios: [Double]
        let mealNames: String
        let supplementNames: String
    }

    private static func dietInputs(for day: Date, limits: NutrientLimits,
                                   in ctx: NSManagedObjectContext) -> DietInputs? {
        let foodRequest = FoodEntry.fetchRequest()
        foodRequest.predicate = dayPredicate(day, key: "timestamp")
        foodRequest.sortDescriptors = [NSSortDescriptor(keyPath: \FoodEntry.timestamp, ascending: true)]
        let food = (try? ctx.fetch(foodRequest)) ?? []
        guard !food.isEmpty else { return nil }

        let supplementRequest = SupplementLog.fetchRequest()
        supplementRequest.predicate = dayPredicate(day, key: "timestamp")
        let supplements = (try? ctx.fetch(supplementRequest)) ?? []

        let intake = NutritionAnalysis.sum(food.map(\.analysis) + supplements.compactMap(\.snapshotNutrients))
        let micros: [(Double, Double)] = [
            (intake.ironMg, limits.iron.reference),
            (intake.zincMg, limits.zinc.reference),
            (intake.magnesiumMg, limits.magnesium.reference),
            (intake.potassiumMg, limits.potassium.reference),
            (intake.calciumMg, limits.calcium.reference),
            (intake.vitaminCMg, limits.vitaminC.reference),
            (intake.vitaminDUg, limits.vitaminD.reference),
            (intake.vitaminB12Ug, limits.vitaminB12.reference),
            (intake.folateUg, limits.folate.reference)
        ]
        return DietInputs(
            intake: intake,
            microRatios: micros.map { $0.1 > 0 ? $0.0 / $0.1 : 0 },
            mealNames: food.prefix(12).map { String(($0.dishName ?? "Meal").prefix(60)) }.joined(separator: ", "),
            supplementNames: supplements.compactMap(\.name).joined(separator: ", ")
        )
    }

    private static func evaluationCreatingIfNeeded(for day: Date, in ctx: NSManagedObjectContext) -> DailyEvaluation {
        if let existing = evaluation(for: day, in: ctx) { return existing }
        let created = DailyEvaluation(context: ctx)
        created.id = UUID()
        created.date = Calendar.current.startOfDay(for: day)
        return created
    }

    private static func fetchProfile(in ctx: NSManagedObjectContext) -> UserProfile? {
        let request = UserProfile.fetchRequest()
        request.fetchLimit = 1
        return try? ctx.fetch(request).first
    }

    private static func fetchTodayCheckIn(in ctx: NSManagedObjectContext) -> DailyCheckIn? {
        let request = DailyCheckIn.fetchRequest()
        request.predicate = DailyCheckIn.todayPredicate()
        request.fetchLimit = 1
        return try? ctx.fetch(request).first
    }

    private static func fetchRecentCheckIns(in ctx: NSManagedObjectContext) -> [DailyCheckIn] {
        let request = DailyCheckIn.fetchRequest()
        request.predicate = DailyCheckIn.lastDaysPredicate(7)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \DailyCheckIn.date, ascending: true)]
        return (try? ctx.fetch(request)) ?? []
    }

    private static func dayPredicate(_ day: Date, key: String) -> NSPredicate {
        let start = Calendar.current.startOfDay(for: day)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        return NSPredicate(format: "%K >= %@ AND %K < %@", key, start as NSDate, key, end as NSDate)
    }
}
