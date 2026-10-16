import Foundation

nonisolated enum SleepTimerText {
    static let minimumHours = 3.0
    static let maximumHours = 14.0

    static func caption(startedAt: Date, now: Date, timeZone: TimeZone = .current) -> String {
        let hours = now.timeIntervalSince(startedAt) / 3600
        if hours > maximumHours {
            return "The sleep timer has been on for more than 14 hours, so it is ignored. Tap the moon to reset it."
        }
        if hours >= minimumHours {
            let minutes = Int((hours * 4).rounded()) * 15
            let rest = minutes % 60
            let length = rest == 0 ? "\(minutes / 60) h" : "\(minutes / 60) h \(rest) min"
            return "About \(length) since you went to bed. Do the check-in to save your sleep; it switches the moon off."
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.timeZone = timeZone
        formatter.dateFormat = "HH:mm"
        return "Sleep timer on since \(formatter.string(from: startedAt)). Leave it on overnight: the morning check-in fills in your hours and switches it off."
    }
}
