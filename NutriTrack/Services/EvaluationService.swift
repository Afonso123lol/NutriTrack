import CoreData

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

    static func dietHistoryPredicate(since start: Date) -> NSPredicate {
        NSPredicate(format: "date >= %@ AND closedAt != nil AND isLogComplete == YES", start as NSDate)
    }

    static func completeDayIntakes(now: Date = Date(), in ctx: NSManagedObjectContext) -> [DayNutrients] {
        completeDays(now: now, in: ctx).map(\.nutrients)
    }

    static func foodWeekDays(now: Date = Date(), in ctx: NSManagedObjectContext) -> [FoodWeek.Day] {
        completeDays(now: now, in: ctx).map { day, nutrients in
            let total = NutritionAnalysis.sum([nutrients.food, nutrients.supplements])
            let isLong = TrainingService.sessions(from: day, to: TrainingService.shifted(day, days: 1), in: ctx)
                .contains { $0.durationMin > TrainingService.longSessionMinutes }
            return FoodWeek.Day(calories: total.calories, proteinG: total.proteinG, fiberG: total.fiberG,
                                saturatedFatG: total.saturatedFatG, sodiumMg: total.sodiumMg, hasLongSession: isLong)
        }
    }

    private static func completeDays(now: Date, in ctx: NSManagedObjectContext) -> [(day: Date, nutrients: DayNutrients)] {
        let today = Calendar.current.startOfDay(for: now)
        guard let start = Calendar.current.date(byAdding: .day, value: 1 - MicronutrientBoard.weekDays, to: today) else {
            return []
        }
        let request = DailyEvaluation.fetchRequest()
        request.predicate = dietHistoryPredicate(since: start)
        let days = ((try? ctx.fetch(request)) ?? []).compactMap(\.date).map(Calendar.current.startOfDay(for:))
        return days.map { day in
            let foodRequest = FoodEntry.fetchRequest()
            foodRequest.predicate = dayPredicate(day, key: "timestamp")
            let supplementRequest = SupplementLog.fetchRequest()
            supplementRequest.predicate = dayPredicate(day, key: "timestamp")
            let food = (try? ctx.fetch(foodRequest)) ?? []
            let supplements = (try? ctx.fetch(supplementRequest)) ?? []
            return (day, DayNutrients(food: NutritionAnalysis.sum(food.map(\.analysis)),
                                      supplements: NutritionAnalysis.sum(supplements.compactMap(\.snapshotNutrients))))
        }
    }

    static func hasFood(on day: Date, in ctx: NSManagedObjectContext) -> Bool {
        let request = FoodEntry.fetchRequest()
        request.predicate = dayPredicate(day, key: "timestamp")
        request.fetchLimit = 1
        return ((try? ctx.count(for: request)) ?? 0) > 0
    }

    @discardableResult
    static func closeDay(_ day: Date, isLogComplete: Bool, now: Date = Date(),
                         in ctx: NSManagedObjectContext) -> Bool {
        guard hasFood(on: day, in: ctx) else { return false }
        let evaluation = evaluationCreatingIfNeeded(for: day, in: ctx)
        evaluation.closedAt = now
        evaluation.isLogComplete = isLogComplete
        try? ctx.save()
        return true
    }

    @discardableResult
    static func autoCloseMissedDays(now: Date = Date(), in ctx: NSManagedObjectContext) -> [Date] {
        let today = Calendar.current.startOfDay(for: now)
        var closed: [Date] = []
        for offset in 1...autoCloseWindowDays {
            guard let day = Calendar.current.date(byAdding: .day, value: -offset, to: today),
                  evaluation(for: day, in: ctx)?.closedAt == nil else { continue }
            let wasComplete = evaluation(for: day, in: ctx)?.isLogComplete ?? false
            if closeDay(day, isLogComplete: wasComplete, now: now, in: ctx) { closed.append(day) }
        }
        return closed
    }

    static func refreshClosedDay(containing date: Date, in ctx: NSManagedObjectContext) {
        guard let evaluation = evaluation(for: date, in: ctx), evaluation.closedAt != nil,
              !hasFood(on: date, in: ctx) else { return }
        evaluation.closedAt = nil
        try? ctx.save()
    }

    private static func evaluationCreatingIfNeeded(for day: Date, in ctx: NSManagedObjectContext) -> DailyEvaluation {
        if let existing = evaluation(for: day, in: ctx) { return existing }
        let created = DailyEvaluation(context: ctx)
        created.id = UUID()
        created.date = Calendar.current.startOfDay(for: day)
        return created
    }

    private static func dayPredicate(_ day: Date, key: String) -> NSPredicate {
        let start = Calendar.current.startOfDay(for: day)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        return NSPredicate(format: "%K >= %@ AND %K < %@", key, start as NSDate, key, end as NSDate)
    }
}
