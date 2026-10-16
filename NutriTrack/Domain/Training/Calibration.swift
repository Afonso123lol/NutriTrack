import Foundation

nonisolated enum YellowMode: String, CaseIterable, Sendable {
    case suggest
    case auto
    case off

    var label: String {
        switch self {
        case .suggest: return "Keep suggesting"
        case .auto: return "Adjust the plan automatically"
        case .off: return "Turn off"
        }
    }
}

nonisolated enum Calibration {
    static let minimumWeeks = 8.0
    static let maximumWeeks = 12.0
    static let minimumYellowDays = 10

    static func weeksDone(startedAt: Date?, now: Date) -> Int {
        guard let startedAt else { return 0 }
        return max(0, Int(now.timeIntervalSince(startedAt) / (7 * 86400)))
    }

    static func isRunning(startedAt: Date?, now: Date, yellowDaysWithSession: Int) -> Bool {
        guard let startedAt else { return false }
        let weeks = now.timeIntervalSince(startedAt) / (7 * 86400)
        if weeks >= maximumWeeks { return false }
        return !(weeks >= minimumWeeks && yellowDaysWithSession >= minimumYellowDays)
    }

    static func mode(stored: String?, startedAt: Date?, now: Date, yellowDaysWithSession: Int) -> YellowMode {
        if isRunning(startedAt: startedAt, now: now, yellowDaysWithSession: yellowDaysWithSession) { return .suggest }
        return YellowMode(rawValue: stored ?? "") ?? .suggest
    }
}
