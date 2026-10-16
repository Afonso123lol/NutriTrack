import Foundation

nonisolated struct WeighIn: Equatable, Sendable {
    let date: Date
    let weightKg: Double
    var context: WeighInContext = .fasted
}

nonisolated struct WeightRate: Equatable, Sendable {
    let slopeKgPerDay: Double
    let standardError: Double
    let count: Int
    let isValid: Bool
    var daytimeOffsetKg: Double? = nil

    var kgPerWeek: Double { slopeKgPerDay * 7 }
}

nonisolated enum WeightTrend {
    static let dailyRetention = 0.9
    static let windowDays = 28
    static let minimumWeighIns = 8
    static let minimumPerEdge = 3
    static let minimumPerContext = 3
    static let edgeDays = 10.0
    static let minimumSpanDays = 21.0

    static func firstOfEachDay(_ weighIns: [WeighIn], calendar: Calendar = .current) -> [WeighIn] {
        var firsts: [Date: WeighIn] = [:]
        for weighIn in weighIns where weighIn.context != .afterTraining {
            let day = calendar.startOfDay(for: weighIn.date)
            if let existing = firsts[day] {
                let isSameContext = existing.context == weighIn.context
                let isBetter = isSameContext ? weighIn.date < existing.date : weighIn.context == .fasted
                if !isBetter { continue }
            }
            firsts[day] = weighIn
        }
        return firsts.values.sorted { $0.date < $1.date }
    }

    static func ema(_ weighIns: [WeighIn], daytimeOffsetKg: Double? = nil,
                    calendar: Calendar = .current) -> [WeighIn] {
        let daily = firstOfEachDay(weighIns, calendar: calendar)
        let hasFasted = daily.contains { $0.context == .fasted }
        let points = daily.compactMap { point -> WeighIn? in
            guard point.context == .daytime else { return point }
            if let daytimeOffsetKg {
                return WeighIn(date: point.date, weightKg: point.weightKg - daytimeOffsetKg, context: .daytime)
            }
            return hasFasted ? nil : point
        }
        guard var trend = points.first?.weightKg, var previous = points.first?.date else { return [] }
        var result = [WeighIn(date: previous, weightKg: trend)]
        for point in points.dropFirst() {
            let days = max(1, point.date.timeIntervalSince(previous) / 86400)
            trend += (1 - pow(dailyRetention, days)) * (point.weightKg - trend)
            previous = point.date
            result.append(WeighIn(date: point.date, weightKg: trend))
        }
        return result
    }

    static func rate(_ weighIns: [WeighIn], now: Date, calendar: Calendar = .current) -> WeightRate {
        let start = now.addingTimeInterval(-Double(windowDays) * 86400)
        let window = firstOfEachDay(weighIns, calendar: calendar).filter { $0.date >= start && $0.date <= now }
        let groups = [WeighInContext.fasted, .daytime]
            .map { context in window.filter { $0.context == context } }
            .filter { $0.count >= minimumPerContext }
        let count = groups.isEmpty ? window.count : groups.reduce(0) { $0 + $1.count }
        let invalid = WeightRate(slopeKgPerDay: 0, standardError: 0, count: count, isValid: false)

        func x(_ point: WeighIn) -> Double { point.date.timeIntervalSince(start) / 86400 }
        func mean(_ values: [Double]) -> Double { values.reduce(0, +) / Double(values.count) }

        var sxx = 0.0
        var sxy = 0.0
        for group in groups {
            let meanX = mean(group.map(x))
            let meanY = mean(group.map(\.weightKg))
            for point in group {
                sxx += (x(point) - meanX) * (x(point) - meanX)
                sxy += (x(point) - meanX) * (point.weightKg - meanY)
            }
        }
        let freedom = Double(count - groups.count - 1)
        guard sxx > 0, freedom > 0 else { return invalid }
        let slope = sxy / sxx

        var residual = 0.0
        var intercepts: [WeighInContext: Double] = [:]
        for group in groups {
            let intercept = mean(group.map(\.weightKg)) - slope * mean(group.map(x))
            intercepts[group[0].context] = intercept
            for point in group {
                let error = point.weightKg - (intercept + slope * x(point))
                residual += error * error
            }
        }
        let standardError = (residual / freedom / sxx).squareRoot()
        let offset = intercepts[.daytime].flatMap { daytime in intercepts[.fasted].map { daytime - $0 } }

        let xs = groups.flatMap { $0 }.map(x).sorted()
        let early = xs.filter { $0 <= edgeDays }.count
        let late = xs.filter { $0 >= Double(windowDays) - edgeDays }.count
        let span = (xs.last ?? 0) - (xs.first ?? 0)
        let isValid = count >= minimumWeighIns && early >= minimumPerEdge && late >= minimumPerEdge
            && span >= minimumSpanDays
        return WeightRate(slopeKgPerDay: slope, standardError: standardError, count: count, isValid: isValid,
                          daytimeOffsetKg: offset)
    }
}
