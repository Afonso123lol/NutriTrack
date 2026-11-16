import Foundation

nonisolated struct SleepSummary: Equatable, Sendable {
    nonisolated struct Night: Equatable, Sendable {
        let hours: Double
        let quality: Int
        let bedtime: Date?
        let dayEnergy: Int
    }

    nonisolated enum RegularityBand: Equatable, Sendable {
        case steady, fair, irregular, veryIrregular

        init(minutes: Double) {
            switch minutes {
            case ...30: self = .steady
            case ...60: self = .fair
            case ...90: self = .irregular
            default: self = .veryIrregular
            }
        }

        var text: String {
            switch self {
            case .steady: return "30 min or less"
            case .fair: return "31 to 60 min"
            case .irregular: return "61 to 90 min"
            case .veryIrregular: return "more than 90 min"
            }
        }
    }

    nonisolated struct Regularity: Equatable, Sendable {
        let minutes: Double
        var roundedMinutes: Int { Int(minutes.rounded()) }
        var band: RegularityBand { RegularityBand(minutes: Double(roundedMinutes)) }
        var text: String { "Bedtime varies by \(roundedMinutes) min" }
    }

    nonisolated struct EnergyBand: Equatable, Sendable {
        let label: String
        let nights: Int
        let averageEnergy: Double?
    }

    static let enoughHours = 7.0
    static let nightsForRegularity = 5
    static let nightsForEnergy = 28
    static let eveningStartMinutes = 18 * 60

    let averageHours: Double?
    let nightsWithEnough: Int
    let nightsCounted: Int
    let averageQuality: Double?
    let regularity: Regularity?
    let energyByHours: [EnergyBand]?

    var averageText: String? {
        guard let averageHours else { return nil }
        if nightsCounted >= 7 { return String(format: "7-night average %.1f h", averageHours) }
        return String(format: "Average %.1f h over %d %@", averageHours, nightsCounted, nightsCounted == 1 ? "night" : "nights")
    }
    var enoughNightsText: String? {
        nightsCounted > 0 ? "\(nightsWithEnough) of \(nightsCounted) nights with 7 h or more" : nil
    }

    static func make(lastSeven: [Night], recent: [Night], calendar: Calendar = .current) -> SleepSummary {
        let slept = lastSeven.filter { $0.hours > 0 }
        let rated = lastSeven.filter { (1...5).contains($0.quality) }
        return SleepSummary(
            averageHours: slept.isEmpty ? nil : slept.map(\.hours).reduce(0, +) / Double(slept.count),
            nightsWithEnough: slept.filter { $0.hours >= enoughHours }.count,
            nightsCounted: slept.count,
            averageQuality: rated.isEmpty ? nil : Double(rated.map(\.quality).reduce(0, +)) / Double(rated.count),
            regularity: regularity(lastSeven.compactMap(\.bedtime), calendar: calendar),
            energyByHours: energyByHours(recent))
    }

    private static func regularity(_ bedtimes: [Date], calendar: Calendar) -> Regularity? {
        guard bedtimes.count >= nightsForRegularity else { return nil }
        let minutes = bedtimes.map { date -> Double in
            let parts = calendar.dateComponents([.hour, .minute], from: date)
            let ofDay = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            return Double((ofDay - eveningStartMinutes + 1440) % 1440)
        }
        let mean = minutes.reduce(0, +) / Double(minutes.count)
        let variance = minutes.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(minutes.count)
        return Regularity(minutes: variance.squareRoot())
    }

    private static func energyByHours(_ nights: [Night]) -> [EnergyBand]? {
        let usable = nights.filter { $0.hours > 0 && (1...5).contains($0.dayEnergy) }
        guard usable.count >= nightsForEnergy else { return nil }
        let bands: [(String, (Double) -> Bool)] = [
            ("Under 7 h", { $0 < 7 }),
            ("7 to 8 h", { $0 >= 7 && $0 < 8 }),
            ("8 to 9 h", { $0 >= 8 && $0 < 9 }),
            ("9 h or more", { $0 >= 9 })
        ]
        return bands.map { label, contains in
            let inBand = usable.filter { contains($0.hours) }
            let average = inBand.isEmpty ? nil : Double(inBand.map(\.dayEnergy).reduce(0, +)) / Double(inBand.count)
            return EnergyBand(label: label, nights: inBand.count, averageEnergy: average)
        }
    }
}
