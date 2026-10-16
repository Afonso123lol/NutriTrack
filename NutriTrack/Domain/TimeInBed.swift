import Foundation

nonisolated enum TimeInBed {
    static let range = SleepTimerText.minimumHours...12.0
    static let step = 0.25
    static let minuteOptions = [0, 15, 30, 45]

    static func hours(bedtime: Date?, wakeTime: Date) -> Double? {
        guard let bedtime else { return nil }
        let hours = wakeTime.timeIntervalSince(bedtime) / 3600
        guard hours >= SleepTimerText.minimumHours, hours <= SleepTimerText.maximumHours else { return nil }
        return min((hours / step).rounded() * step, range.upperBound)
    }

    static func prefill(bedtime: Date?, wakeTime: Date) -> Double {
        hours(bedtime: bedtime, wakeTime: wakeTime) ?? CheckInAnswers(wakeTime: wakeTime).sleepHours
    }

    static func validBedtime(_ bedtime: Date?, wakeTime: Date) -> Date? {
        hours(bedtime: bedtime, wakeTime: wakeTime) == nil ? nil : bedtime
    }

    static func label(_ hours: Double) -> String {
        let minutes = Int((hours * 60).rounded())
        let rest = minutes % 60
        return rest == 0 ? "\(minutes / 60) h" : "\(minutes / 60) h \(rest) min"
    }

    static func split(_ hours: Double) -> (hours: Int, minutes: Int) {
        let clamped = min(max(hours, range.lowerBound), range.upperBound)
        let quarters = Int((clamped / step).rounded())
        return (quarters / 4, quarters % 4 * 15)
    }

    static func combine(hours: Int, minutes: Int) -> Double {
        min(max(Double(hours) + Double(minutes) / 60, range.lowerBound), range.upperBound)
    }
}
