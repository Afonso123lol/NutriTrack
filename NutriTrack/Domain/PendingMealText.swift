import Foundation

nonisolated enum PendingMealText {
    static func elapsed(since start: Date, now: Date) -> String {
        let minutes = Int(max(0, now.timeIntervalSince(start)) / 60)
        if minutes < 1 { return "Sent just now" }
        if minutes < 60 { return "Sent \(minutes) min ago" }
        let hours = minutes / 60
        let rest = minutes % 60
        return rest == 0 ? "Sent \(hours) h ago" : "Sent \(hours) h \(rest) min ago"
    }

    static func waiting(attempt: Int?) -> String {
        guard let attempt, attempt > 0 else { return "Waiting for the answer" }
        return "Retrying · attempt \(attempt + 1)"
    }
}
