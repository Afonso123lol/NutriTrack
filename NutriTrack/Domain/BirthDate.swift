import Foundation

nonisolated enum BirthDate {
    static let minimumAge = 14
    static let maximumAge = 100

    static func age(bornOn birthDate: Date, now: Date, calendar: Calendar = .current) -> Int {
        max(0, calendar.dateComponents([.year], from: birthDate, to: now).year ?? 0)
    }

    static func isBirthday(bornOn birthDate: Date, now: Date, calendar: Calendar = .current) -> Bool {
        let born = calendar.dateComponents([.month, .day], from: birthDate)
        let today = calendar.dateComponents([.year, .month, .day], from: now)
        if born.month == today.month && born.day == today.day { return true }
        guard born.month == 2, born.day == 29, today.month == 2, today.day == 28, let year = today.year else { return false }
        let isLeapYear = (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
        return !isLeapYear
    }

    static func allowedRange(now: Date, calendar: Calendar = .current) -> ClosedRange<Date> {
        let earliest = calendar.date(byAdding: .year, value: -maximumAge, to: now) ?? now
        let latest = calendar.date(byAdding: .year, value: -minimumAge, to: now) ?? now
        return earliest...latest
    }

    static func suggested(now: Date, calendar: Calendar = .current) -> Date {
        let year = calendar.component(.year, from: now) - 25
        return calendar.date(from: DateComponents(year: year, month: 1, day: 1)) ?? now
    }
}
