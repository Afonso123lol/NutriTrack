import Foundation

nonisolated enum NutrientStatus: Sendable {
    case low
    case good
    case over

    static func of(value: Double, min: Double, max: Double, invert: Bool) -> NutrientStatus {
        let ratio = value / Swift.max(max, 1)
        if invert {
            if ratio > 1.0 { return .over }
            return ratio > 0.8 ? .low : .good
        }
        if value < min { return .low }
        return ratio > 1.0 ? .over : .good
    }

    static func of(value: Double, min: Double, supplemental: Double, supplementalMax: Double) -> NutrientStatus {
        if supplemental > supplementalMax { return .over }
        return value < min ? .low : .good
    }
}
