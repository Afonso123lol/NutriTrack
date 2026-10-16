import Foundation

nonisolated enum ReferenceSource: String, Sendable {
    case efsa = "EFSA"
    case dri = "DRI"
}

nonisolated enum UpperScope: Sendable {
    case total
    case supplementsOnly
}

nonisolated struct NutrientReference: Equatable, Sendable {
    let reference: Double
    var averageRequirement: Double? = nil
    var upper: Double? = nil
    var upperScope = UpperScope.total
    var isUpperSafeLevel = false
    var source = ReferenceSource.efsa
    var upperSource = ReferenceSource.efsa

    var basis: String {
        let origin = "Reference: \(source.rawValue)."
        guard upper != nil else { return origin + " No upper level set." }
        let label = isUpperSafeLevel ? "Safe level" : "Upper level"
        let scope = upperScope == .supplementsOnly ? ", supplements only" : ""
        return "\(origin) \(label): \(upperSource.rawValue)\(scope)."
    }
}
