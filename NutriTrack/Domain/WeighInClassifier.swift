import Foundation

nonisolated enum WeighInContext: Sendable {
    case fasted
    case daytime
    case afterTraining
}

nonisolated enum WeighInClassifier {
    static let fastedHoursAfterWaking = 3.0
    static let morningEndsAtHour = 11
    static let hoursAfterTraining = 3.0
    static let minutesIntoSessionStillBefore = 15.0

    static func context(at date: Date, wokeAt: Date?, firstMealAt: Date?, sessions: [DateInterval],
                        calendar: Calendar = .current) -> WeighInContext {
        let isAfterTraining = sessions.contains { session in
            date > session.start.addingTimeInterval(minutesIntoSessionStillBefore * 60)
                && date <= session.end.addingTimeInterval(hoursAfterTraining * 3600)
        }
        if isAfterTraining { return .afterTraining }
        if let firstMealAt, date >= firstMealAt { return .daytime }
        if let wokeAt {
            return date <= wokeAt.addingTimeInterval(fastedHoursAfterWaking * 3600) ? .fasted : .daytime
        }
        return calendar.component(.hour, from: date) < morningEndsAtHour ? .fasted : .daytime
    }

    static func wakeTime(checkedInAt: Date?, bedtime: Date?, sleepHours: Double) -> Date? {
        guard let bedtime, sleepHours > 0 else { return checkedInAt }
        let estimate = bedtime.addingTimeInterval(sleepHours * 3600)
        guard let checkedInAt else { return estimate }
        return min(estimate, checkedInAt)
    }
}
