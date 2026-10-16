import Foundation

nonisolated struct WeekPath: Equatable, Sendable {
    nonisolated enum Status: Sendable {
        case onPath
        case behind
        case ahead

        var label: String {
            switch self {
            case .onPath: return "On your path"
            case .behind: return "A little behind"
            case .ahead: return "Ahead of plan"
            }
        }
    }

    nonisolated struct Day: Equatable, Sendable {
        let planned: Double
        let done: Double
        let hasSession: Bool
    }

    static let lowerShare = 0.85
    static let upperShare = 1.10

    let days: [Day]
    let todayIndex: Int
    let status: Status

    var totalPlanned: Double { days.last?.planned ?? 0 }
    var doneSoFar: Double { days[todayIndex].done }

    func lower(at index: Int) -> Double { days[index].planned * Self.lowerShare }
    func upper(at index: Int) -> Double { days[index].planned * Self.upperShare }

    static func make(plannedByDay: [Double], doneByDay: [Double], todayIndex: Int) -> WeekPath {
        let today = min(max(todayIndex, 0), 6)
        func value(_ values: [Double], _ index: Int) -> Double { index < values.count ? max(values[index], 0) : 0 }

        var days: [Day] = []
        var planned = 0.0
        var done = 0.0
        for index in 0..<7 {
            planned += value(plannedByDay, index)
            if index <= today { done += value(doneByDay, index) }
            days.append(Day(planned: planned, done: done, hasSession: value(plannedByDay, index) > 0))
        }

        let didTrainToday = value(doneByDay, today) > 0
        let owed = didTrainToday ? days[today].planned : (today > 0 ? days[today - 1].planned : 0)
        let doneNow = days[today].done
        let tolerance = 0.0001
        var status = Status.onPath
        if doneNow + tolerance < owed * lowerShare {
            status = .behind
        } else if days[today].planned > 0, doneNow > days[today].planned * upperShare + tolerance {
            status = .ahead
        } else if days[today].planned == 0, doneNow > tolerance, planned > 0 {
            status = .ahead
        }
        return WeekPath(days: days, todayIndex: today, status: status)
    }
}
