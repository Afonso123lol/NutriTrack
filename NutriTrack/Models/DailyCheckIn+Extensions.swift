import CoreData

extension DailyCheckIn {
    static func create(_ answers: CheckInAnswers, bedtime: Date?, now: Date = Date(), in ctx: NSManagedObjectContext) {
        let c = DailyCheckIn(context: ctx)
        c.id = UUID()
        c.date = Calendar.current.startOfDay(for: answers.wakeTime)
        c.energyLevel = Int16(answers.energy)
        c.sleepHours = answers.sleepHours
        c.sleepQuality = Int16(answers.quality)
        c.soreness = Int16(answers.soreness)
        c.stress = Int16(answers.stress)
        c.bedtime = bedtime
        c.isSick = answers.isSick
        c.hasPain = answers.hasPain
        c.wakeTime = answers.wakeTime
        let profileRequest = UserProfile.fetchRequest()
        profileRequest.fetchLimit = 1
        if let profile = (try? ctx.fetch(profileRequest))?.first, profile.calibrationStartedAt == nil {
            profile.calibrationStartedAt = c.date
        }
        try? ctx.save()
    }

    static func on(_ day: Date, in ctx: NSManagedObjectContext) -> DailyCheckIn? {
        let start = Calendar.current.startOfDay(for: day)
        guard let end = Calendar.current.date(byAdding: .day, value: 1, to: start) else { return nil }
        let request = DailyCheckIn.fetchRequest()
        request.predicate = NSPredicate(format: "date >= %@ AND date < %@", start as NSDate, end as NSDate)
        request.fetchLimit = 1
        return (try? ctx.fetch(request))?.first
    }

    func recordDayEnergy(_ level: Int, in ctx: NSManagedObjectContext) {
        guard (1...5).contains(level) else { return }
        dayEnergy = Int16(level)
        try? ctx.save()
    }

    var suggestionChoiceValue: SuggestionChoice? { suggestionChoice.flatMap(SuggestionChoice.init(rawValue:)) }

    func recordSuggestion(_ choice: SuggestionChoice, in ctx: NSManagedObjectContext) {
        suggestionChoice = choice.rawValue
        try? ctx.save()
    }

    static func todayPredicate() -> NSPredicate {
        let start = Calendar.current.startOfDay(for: Date())
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        return NSPredicate(format: "date >= %@ AND date < %@", start as NSDate, end as NSDate)
    }

    static func lastDaysPredicate(_ days: Int) -> NSPredicate {
        let start = Calendar.current.date(byAdding: .day, value: -days,
                                          to: Calendar.current.startOfDay(for: Date()))!
        return NSPredicate(format: "date >= %@", start as NSDate)
    }
}
