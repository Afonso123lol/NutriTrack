import Foundation

nonisolated enum EveningQuestion {
    static let lateNightEndsAtHour = 5

    static func day(for now: Date, calendar: Calendar = .current) -> Date {
        let start = calendar.startOfDay(for: now)
        guard calendar.component(.hour, from: now) < lateNightEndsAtHour else { return start }
        return calendar.date(byAdding: .day, value: -1, to: start) ?? start
    }

    static func shouldAsk(hasCheckIn: Bool, dayEnergy: Int) -> Bool {
        hasCheckIn && dayEnergy == 0
    }
}
