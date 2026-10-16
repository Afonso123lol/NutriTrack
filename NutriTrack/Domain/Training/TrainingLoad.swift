import Foundation

nonisolated struct LoggedSession: Equatable, Sendable {
    let isStrength: Bool
    let durationMin: Double
    let rpe: Int
    let elevationGainM: Double
}

nonisolated enum LoadWarning: Hashable, Sendable {
    case weeklyJump(percent: Int)
    case twoWeekJump(percent: Int)
    case sessionPeak(minutes: Int)
    case longShare(percent: Int)

    var text: String {
        switch self {
        case .weeklyJump(let percent):
            return "This week is \(percent)% above last week. A warning, not a diagnosis: jumps above 10% are where problems tend to start."
        case .twoWeekJump(let percent):
            return "This week is \(percent)% above two weeks ago. A warning, not a diagnosis: ease off for a few days."
        case .sessionPeak(let minutes):
            return "A \(minutes) minute session is more than 10% longer than anything in your last 30 days."
        case .longShare(let percent):
            return "Your longest session is \(percent)% of the week. Around 25–30% is the usual ceiling."
        }
    }
}

nonisolated struct WeekLoad: Equatable, Sendable {
    let aerobicMinutes: Double
    let load: Double
    let elevationM: Double
    let sessions: Int
    let warnings: [LoadWarning]
}

nonisolated enum TrainingLoad {
    static let weeklyJump = 0.10
    static let twoWeekJump = 0.30
    static let sessionPeak = 1.10
    static let longShare = 0.30

    static func summarize(week: [LoggedSession], previousWeekMinutes: Double?, twoWeeksAgoMinutes: Double?,
                          longestBefore: Double) -> WeekLoad {
        let aerobic = week.filter { !$0.isStrength }
        let minutes = aerobic.reduce(0) { $0 + $1.durationMin }
        var warnings: [LoadWarning] = []

        if let earlier = twoWeeksAgoMinutes, earlier > 0, minutes > earlier * (1 + twoWeekJump) {
            warnings.append(.twoWeekJump(percent: Int(((minutes / earlier - 1) * 100).rounded())))
        } else if let previous = previousWeekMinutes, previous > 0, minutes > previous * (1 + weeklyJump) {
            warnings.append(.weeklyJump(percent: Int(((minutes / previous - 1) * 100).rounded())))
        }
        let longest = aerobic.map(\.durationMin).max() ?? 0
        if longestBefore > 0, longest > longestBefore * sessionPeak {
            warnings.append(.sessionPeak(minutes: Int(longest.rounded())))
        }
        if aerobic.count >= 4, minutes > 0, longest / minutes > longShare {
            warnings.append(.longShare(percent: Int((longest / minutes * 100).rounded())))
        }
        return WeekLoad(aerobicMinutes: minutes,
                        load: week.reduce(0) { $0 + Double($1.rpe) * $1.durationMin },
                        elevationM: week.reduce(0) { $0 + $1.elevationGainM },
                        sessions: week.count, warnings: warnings)
    }
}
