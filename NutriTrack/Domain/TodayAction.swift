import Foundation

nonisolated enum TodayAction: Equatable, Sendable {
    case checkIn
    case session
    case closeDay
    case dayClosed

    static let closeHour = 19

    static func pick(hasCheckIn: Bool, hasSessionToLog: Bool, mealsToday: Int, isDayClosed: Bool,
                     hour: Int) -> TodayAction? {
        if !hasCheckIn { return .checkIn }
        if hasSessionToLog { return .session }
        if isDayClosed { return .dayClosed }
        if mealsToday > 0 && hour >= closeHour { return .closeDay }
        return nil
    }
}
