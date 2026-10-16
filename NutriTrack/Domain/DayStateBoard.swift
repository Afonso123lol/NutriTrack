import Foundation

nonisolated struct DayStateBoard: Equatable, Sendable {
    nonisolated struct Entry: Equatable, Sendable {
        let energy: Int
        let soreness: Int
        let stress: Int
        let isSick: Bool
        let hasPain: Bool
    }

    nonisolated enum Band: Equatable, Sendable {
        case wellBelow, below, within, above, wellAbove

        var text: String {
            switch self {
            case .wellBelow: return "Well below your usual"
            case .below: return "Below your usual"
            case .within: return "Within your usual"
            case .above: return "Above your usual"
            case .wellAbove: return "Well above your usual"
            }
        }

        var arrow: String? {
            switch self {
            case .wellBelow, .below: return "↓"
            case .within: return nil
            case .above, .wellAbove: return "↑"
            }
        }
    }

    nonisolated struct ScaleRow: Equatable, Sendable {
        let title: String
        let value: Int
        let usual: Int?
        let band: Band?
        let isUnfavourable: Bool

        var valueText: String { "\(title) · \(value) of 5" }
        var usualText: String? { usual.map { "usually \($0)" } }
        var bandText: String? { band.map { [$0.arrow, $0.text].compactMap { $0 }.joined(separator: " ") } }
    }

    nonisolated struct SleepRow: Equatable, Sendable {
        let hours: Double
        let need: Double

        var fraction: Double { min(hours / need, 1) }
        var isShort: Bool { hours <= DayReadiness.yellowSleepHours }
        var valueText: String { "Sleep · \(DayHeadline.hours(hours)) h" }
        var needText: String { "need \(DayHeadline.hours(need)) h" }
    }

    static let windowDays = 28
    static let minimumDays = DayReadiness.minimumBaselineDays

    let sleep: SleepRow?
    let rows: [ScaleRow]
    let isIll: Bool
    let hasPain: Bool
    let baselineDays: Int

    var footer: String {
        baselineDays >= Self.minimumDays
            ? "Baseline: \(baselineDays) of \(Self.windowDays) days"
            : "Still learning your usual: \(baselineDays) of \(Self.minimumDays) days"
    }

    static func make(today: Entry, history: [Entry], sleepHours: Double?, sleepNeed: Double) -> DayStateBoard {
        let usable = history.filter { !$0.isSick }
        let rows = [
            row("Energy", today.energy, usable.map(\.energy), lowerIsWorse: true),
            row("Soreness", today.soreness, usable.map(\.soreness), lowerIsWorse: false),
            row("Stress", today.stress, usable.map(\.stress), lowerIsWorse: false)
        ]
        let sleep = sleepHours.flatMap { $0 > 0 ? SleepRow(hours: $0, need: sleepNeed) : nil }
        return DayStateBoard(sleep: sleep, rows: rows, isIll: today.isSick, hasPain: today.hasPain,
                             baselineDays: usable.count)
    }

    private static func row(_ title: String, _ value: Int, _ history: [Int], lowerIsWorse: Bool) -> ScaleRow {
        let values = history.filter { (1...5).contains($0) }.map(Double.init)
        guard values.count >= minimumDays, (1...5).contains(value) else {
            return ScaleRow(title: title, value: value, usual: nil, band: nil, isUnfavourable: false)
        }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(values.count)
        let deviation = (Double(value) - mean) / max(variance.squareRoot(), DayReadiness.minimumSpread)
        let band: Band
        switch deviation {
        case ...(-2): band = .wellBelow
        case ...(-1): band = .below
        case 2...: band = .wellAbove
        case 1...: band = .above
        default: band = .within
        }
        let isUnfavourable = lowerIsWorse ? deviation <= -1 : deviation >= 1
        return ScaleRow(title: title, value: value, usual: Int(mean.rounded()), band: band,
                        isUnfavourable: isUnfavourable)
    }
}
