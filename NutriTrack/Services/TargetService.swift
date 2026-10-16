import CoreData

enum TargetService {
    static let trendLookbackDays = 90.0

    static func weekStart(for date: Date) -> Date {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .current
        return calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? Calendar.current.startOfDay(for: date)
    }

    static func input(for profile: UserProfile, weightKg: Double, tdee: Double) -> TargetInput {
        TargetInput(sex: profile.sexEnum, age: Int(profile.age), weightKg: weightKg, heightCm: profile.heightCm,
                    direction: profile.goalEnum.direction, ratePercent: profile.weeklyRatePercent, tdee: tdee,
                    highProtein: profile.goalEnum.prefersHighProtein)
    }

    static func currentPlan(for profile: UserProfile) -> (plan: PlannedTargets, weightKg: Double) {
        if let ctx = profile.managedObjectContext, let snapshot = latestSnapshot(before: nil, in: ctx),
           snapshot.goal == profile.goal, snapshot.ratePercent == profile.weeklyRatePercent,
           snapshot.trendWeightKg > 0 {
            let planned = TargetPlanner.plan(input(for: profile, weightKg: snapshot.trendWeightKg, tdee: snapshot.tdee),
                                             calories: snapshot.calories)
            return (planned, snapshot.trendWeightKg)
        }
        let resting = BodyMetrics.restingRate(sex: profile.sexEnum, age: Int(profile.age),
                                              weightKg: profile.weightKg, heightCm: profile.heightCm)
        let tdee = ExpenditureEstimator.formula(restingRate: resting, activityFactor: profile.activityFactor)
        return (TargetPlanner.plan(input(for: profile, weightKg: profile.weightKg, tdee: tdee)), profile.weightKg)
    }

    static func currentTargets(for profile: UserProfile) -> MacroTargets {
        let current = currentPlan(for: profile)
        return NutritionCalculator.targets(from: current.plan, sex: profile.sexEnum, age: Int(profile.age),
                                           weightKg: current.weightKg, goal: profile.goalEnum)
    }

    static func dayTargets(for profile: UserProfile, plannedMinutes: Double, hardEffort: Bool)
        -> (carbsG: Double, fatG: Double, carbMinimumG: Double?, isShort: Bool) {
        let current = currentPlan(for: profile)
        guard plannedMinutes > 0 else { return (current.plan.carbsG, current.plan.fatG, nil, false) }
        let reference = BodyMetrics.referenceWeight(weightKg: current.weightKg, heightCm: profile.heightCm)
        let minimum = TargetPlanner.carbMinimum(referenceWeightKg: reference, trainingMinutes: plannedMinutes,
                                                hardEffort: hardEffort)
        let day = TargetPlanner.dayMacros(current.plan, carbMinimumG: minimum)
        return (day.carbsG, day.fatG, minimum, day.isShort)
    }

    static func refreshForCurrentProfile(now: Date = Date(), in ctx: NSManagedObjectContext) {
        let request = UserProfile.fetchRequest()
        request.fetchLimit = 1
        guard let profile = try? ctx.fetch(request).first else { return }
        refresh(profile: profile, now: now, in: ctx)
    }

    @discardableResult
    static func refresh(profile: UserProfile, now: Date = Date(), force: Bool = false,
                        in ctx: NSManagedObjectContext) -> TargetSnapshot? {
        guard profile.heightCm > 0, profile.weightKg > 0 else { return nil }
        let week = weekStart(for: now)
        let existing = snapshot(forWeek: week, in: ctx)
        if let existing, !force { return existing }
        let previous = latestSnapshot(before: week, in: ctx)

        let weighIns = fetchWeighIns(since: now.addingTimeInterval(-trendLookbackDays * 86400), in: ctx)
        let rate = WeightTrend.rate(weighIns, now: now)
        let trendWeight = WeightTrend.ema(weighIns, daytimeOffsetKg: rate.daytimeOffsetKg).last?.weightKg
            ?? profile.weightKg
        let complete = completeDays(since: now.addingTimeInterval(-Double(ExpenditureEstimator.windowDays) * 86400),
                                    in: ctx)

        let resting = BodyMetrics.restingRate(sex: profile.sexEnum, age: Int(profile.age),
                                              weightKg: trendWeight, heightCm: profile.heightCm)
        let formula = ExpenditureEstimator.formula(restingRate: resting, activityFactor: profile.activityFactor)
        let wasAdaptive = previous?.tdeeSource == "adaptive"
        let keptThisWeek = !wasAdaptive && existing?.tdeeSource == "adaptive"
        let base = wasAdaptive ? (previous?.tdee ?? formula) : (keptThisWeek ? (existing?.tdee ?? formula) : formula)

        let windowStart = now.addingTimeInterval(-Double(ExpenditureEstimator.windowDays) * 86400)
        let isSettling = profile.goalChangedAt.map {
            $0.addingTimeInterval(ExpenditureEstimator.settlingDays * 86400) > windowStart
        } ?? false
        let result = isSettling || keptThisWeek
            ? ExpenditureResult(tdee: base, status: .settling, completeDays: complete.count)
            : ExpenditureEstimator.update(previousTDEE: base, restingRate: resting, rate: rate,
                                          completeDays: complete, now: now)
        let isAdaptive = wasAdaptive || keptThisWeek || result.status == .updated

        let planInput = input(for: profile, weightKg: trendWeight, tdee: result.tdee)
        let basePlan = TargetPlanner.plan(planInput)
        var calories = basePlan.calories
        var limitedBy = basePlan.limitedBy.rawValue

        var losses = recentLosses(before: week, in: ctx)
        if rate.isValid { losses.append(-rate.kgPerWeek) }
        let sameGoal = previous?.goal == profile.goal && previous?.ratePercent == profile.weeklyRatePercent
        switch basePlan.direction == .lose ? TargetPlanner.safeguard(lossKgPerWeek: losses, weightKg: trendWeight) : .none {
        case .maintenance:
            calories = result.tdee
            limitedBy = "tooFast"
        case .raise:
            calories = min(result.tdee, calories * 1.10)
            limitedBy = "fastLoss"
        case .none:
            if sameGoal { calories = TargetPlanner.limitWeeklyChange(calories, previous: previous?.calories) }
        }
        let plan = TargetPlanner.plan(planInput, calories: calories)

        let snapshot = existing ?? TargetSnapshot(context: ctx)
        if snapshot.id == nil { snapshot.id = UUID() }
        snapshot.weekStart = week
        snapshot.createdAt = now
        snapshot.goal = profile.goal
        snapshot.ratePercent = profile.weeklyRatePercent
        snapshot.calories = plan.calories
        snapshot.proteinG = plan.proteinG
        snapshot.carbsG = plan.carbsG
        snapshot.fatG = plan.fatG
        snapshot.tdee = result.tdee
        snapshot.tdeeSource = isAdaptive ? "adaptive" : "formula"
        snapshot.trendWeightKg = trendWeight
        snapshot.hasMeasuredRate = rate.isValid
        snapshot.measuredRateKgPerWeek = rate.isValid ? rate.kgPerWeek : 0
        snapshot.completeDays = Int16(result.completeDays)
        snapshot.weighIns = Int16(rate.count)
        snapshot.limitedBy = limitedBy
        try? ctx.save()
        return snapshot
    }

    static func snapshot(forWeek week: Date, in ctx: NSManagedObjectContext) -> TargetSnapshot? {
        let request = TargetSnapshot.fetchRequest()
        request.predicate = NSPredicate(format: "weekStart == %@", week as NSDate)
        request.fetchLimit = 1
        return try? ctx.fetch(request).first
    }

    static func latestSnapshot(before week: Date?, in ctx: NSManagedObjectContext) -> TargetSnapshot? {
        let request = TargetSnapshot.fetchRequest()
        if let week { request.predicate = NSPredicate(format: "weekStart < %@", week as NSDate) }
        request.sortDescriptors = [NSSortDescriptor(keyPath: \TargetSnapshot.weekStart, ascending: false)]
        request.fetchLimit = 1
        return try? ctx.fetch(request).first
    }

    static func fetchWeighIns(since start: Date, in ctx: NSManagedObjectContext) -> [WeighIn] {
        let request = WeightEntry.fetchRequest()
        request.predicate = NSPredicate(format: "date >= %@", start as NSDate)
        return classify((try? ctx.fetch(request)) ?? [], in: ctx)
    }

    static func classify(_ entries: [WeightEntry], in ctx: NSManagedObjectContext,
                         calendar: Calendar = .current) -> [WeighIn] {
        let dated = entries.compactMap { entry -> (date: Date, weightKg: Double)? in
            guard let date = entry.date, entry.weightKg > 0 else { return nil }
            return (date, entry.weightKg)
        }
        guard let earliest = dated.map(\.date).min() else { return [] }
        let from = calendar.startOfDay(for: earliest)

        let checkIns = DailyCheckIn.fetchRequest()
        checkIns.predicate = NSPredicate(format: "date >= %@", from as NSDate)
        var wakeTimes: [Date: Date] = [:]
        for checkIn in (try? ctx.fetch(checkIns)) ?? [] {
            guard let day = checkIn.date else { continue }
            wakeTimes[calendar.startOfDay(for: day)] = WeighInClassifier.wakeTime(
                checkedInAt: checkIn.wakeTime, bedtime: checkIn.bedtime, sleepHours: checkIn.sleepHours)
        }

        let meals = NSFetchRequest<NSDictionary>(entityName: "FoodEntry")
        meals.resultType = .dictionaryResultType
        meals.propertiesToFetch = ["timestamp"]
        meals.predicate = NSPredicate(format: "timestamp >= %@", from as NSDate)
        var firstMeals: [Date: Date] = [:]
        for row in (try? ctx.fetch(meals)) ?? [] {
            guard let timestamp = row["timestamp"] as? Date else { continue }
            let day = calendar.startOfDay(for: timestamp)
            firstMeals[day] = min(firstMeals[day] ?? timestamp, timestamp)
        }

        let trained = TrainingSession.fetchRequest()
        trained.predicate = NSPredicate(format: "startedAt >= %@", from.addingTimeInterval(-86400) as NSDate)
        let sessions = ((try? ctx.fetch(trained)) ?? []).compactMap { session in
            session.startedAt.map { DateInterval(start: $0, duration: max(0, session.durationMin) * 60) }
        }

        return dated.map { entry in
            let day = calendar.startOfDay(for: entry.date)
            let context = WeighInClassifier.context(at: entry.date, wokeAt: wakeTimes[day],
                                                    firstMealAt: firstMeals[day], sessions: sessions,
                                                    calendar: calendar)
            return WeighIn(date: entry.date, weightKg: entry.weightKg, context: context)
        }
    }

    private static func recentLosses(before week: Date, in ctx: NSManagedObjectContext) -> [Double] {
        let request = TargetSnapshot.fetchRequest()
        request.predicate = NSPredicate(format: "weekStart < %@", week as NSDate)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \TargetSnapshot.weekStart, ascending: false)]
        request.fetchLimit = 2
        let recent = ((try? ctx.fetch(request)) ?? []).reversed()
        return recent.map { $0.hasMeasuredRate ? -$0.measuredRateKgPerWeek : 0 }
    }

    private static func completeDays(since start: Date, in ctx: NSManagedObjectContext) -> [DayIntake] {
        let calendar = Calendar.current
        let evaluationRequest = DailyEvaluation.fetchRequest()
        evaluationRequest.predicate = NSPredicate(format: "date >= %@ AND isLogComplete == YES AND closedAt != nil",
                                                  calendar.startOfDay(for: start) as NSDate)
        let days = Set(((try? ctx.fetch(evaluationRequest)) ?? []).compactMap { $0.date.map(calendar.startOfDay(for:)) })
        guard !days.isEmpty else { return [] }

        var totals: [Date: Double] = [:]
        let foodRequest = FoodEntry.fetchRequest()
        foodRequest.predicate = NSPredicate(format: "timestamp >= %@", calendar.startOfDay(for: start) as NSDate)
        for meal in (try? ctx.fetch(foodRequest)) ?? [] {
            guard let timestamp = meal.timestamp else { continue }
            totals[calendar.startOfDay(for: timestamp), default: 0] += meal.calories
        }
        let supplementRequest = SupplementLog.fetchRequest()
        supplementRequest.predicate = NSPredicate(format: "timestamp >= %@", calendar.startOfDay(for: start) as NSDate)
        for log in (try? ctx.fetch(supplementRequest)) ?? [] {
            guard let timestamp = log.timestamp else { continue }
            totals[calendar.startOfDay(for: timestamp), default: 0] += log.snapshotNutrients?.calories ?? 0
        }
        return days.compactMap { day in
            totals[day].map { DayIntake(date: day.addingTimeInterval(12 * 3600), calories: $0) }
        }
    }
}
