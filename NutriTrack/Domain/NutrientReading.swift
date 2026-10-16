import Foundation

nonisolated struct NutrientReading: Identifiable, Equatable, Sendable {
    enum Rule: Equatable, Sendable {
        case range
        case floor
        case limit
        case supplementLimit(taken: Double)
        case plain
    }

    let name: String
    let value: Double
    let unit: String
    let floor: Double
    let ceiling: Double
    let rule: Rule
    var showsStatus = true
    var overWord = "Over limit"
    var basis: String? = nil
    var note: String? = nil
    var fromSupplements = 0.0

    var id: String { name }

    var status: NutrientStatus {
        switch rule {
        case .range:
            return NutrientStatus.of(value: value, min: floor, max: ceiling, invert: false)
        case .floor:
            return value < floor ? .low : .good
        case .limit:
            return NutrientStatus.of(value: value, min: floor, max: ceiling, invert: true)
        case .supplementLimit(let taken):
            return NutrientStatus.of(value: value, min: floor, supplemental: taken, supplementalMax: ceiling)
        case .plain:
            return .good
        }
    }

    var word: String {
        guard showsStatus, rule != .plain else { return "" }
        switch (rule, status) {
        case (_, .over): return overWord
        case (.limit, .low): return "Near limit"
        case (.limit, .good): return "Within limit"
        case (_, .low): return "Low"
        case (_, .good): return "On target"
        }
    }

    var geometry: TargetBarGeometry {
        let base: TargetBarGeometry
        switch rule {
        case .range: base = .range(value: value, floor: floor, ceiling: ceiling)
        case .limit: base = .make(value: value, target: ceiling, ceiling: ceiling)
        case .floor, .supplementLimit: base = .make(value: value, target: floor)
        case .plain: base = .make(value: value)
        }
        guard showsStatus else {
            return TargetBarGeometry(fill: base.fill, tick: base.tick, zone: base.zone, isOver: false)
        }
        return base
    }

    var amount: String {
        let eaten = Self.short(value)
        switch rule {
        case .range: return "\(eaten) / \(Self.short(floor))–\(Self.short(ceiling)) \(unit)"
        case .limit: return "\(eaten) / max \(Self.short(ceiling)) \(unit)"
        case .floor, .supplementLimit: return "\(eaten) / \(Self.short(floor))+ \(unit)"
        case .plain: return "\(eaten) \(unit)"
        }
    }

    var supplementNote: String? {
        if case .supplementLimit(let taken) = rule {
            return "From supplements: \(Self.short(taken)) of \(Self.short(ceiling)) \(unit) limit"
        }
        return fromSupplements > 0 ? "From supplements: \(Self.short(fromSupplements)) \(unit)" : nil
    }

    static func short(_ value: Double) -> String {
        if value >= 100 { return String(format: "%.0f", value) }
        let text = String(format: "%.1f", value)
        return text.hasSuffix(".0") ? String(text.dropLast(2)) : text
    }
}
