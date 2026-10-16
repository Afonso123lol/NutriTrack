import Foundation

nonisolated struct WheelValue: Equatable, Sendable {
    let whole: Int
    let tenth: Int

    var value: Double { Double(whole) + Double(tenth) / 10 }

    static func split(_ value: Double, in range: ClosedRange<Int>) -> WheelValue {
        let tenths = Int((value * 10).rounded())
        let clamped = min(max(tenths, range.lowerBound * 10), range.upperBound * 10)
        return WheelValue(whole: clamped / 10, tenth: clamped % 10)
    }

    static func combine(whole: Int, tenth: Int, in range: ClosedRange<Int>) -> Double {
        let tenths = min(max(whole * 10 + tenth, range.lowerBound * 10), range.upperBound * 10)
        return Double(tenths) / 10
    }
}
