import Foundation

nonisolated struct TargetBarGeometry: Equatable, Sendable {
    static let headroom = 1.2

    let fill: Double
    let tick: Double?
    let zone: ClosedRange<Double>?
    let isOver: Bool

    static func make(value: Double, target: Double? = nil, floor: Double? = nil,
                     ceiling: Double? = nil) -> TargetBarGeometry {
        let references = [target, floor, ceiling].compactMap { $0 }.filter { $0 > 0 }
        guard let top = references.max() else {
            return TargetBarGeometry(fill: value > 0 ? 1 : 0, tick: nil, zone: nil, isOver: false)
        }
        let scale = top * headroom
        func position(_ amount: Double) -> Double { min(max(amount / scale, 0), 1) }

        var zone: ClosedRange<Double>?
        if let floor, let ceiling, floor > 0, ceiling > floor {
            zone = position(floor)...position(ceiling)
        }
        let tick = target.flatMap { $0 > 0 ? position($0) : nil }
        let isOver = ceiling.map { $0 > 0 && value > $0 } ?? false
        return TargetBarGeometry(fill: position(value), tick: tick, zone: zone, isOver: isOver)
    }

    static let rangeFloorAt = 0.6
    static let rangeCeilingAt = 0.9

    static func range(value: Double, floor: Double, ceiling: Double) -> TargetBarGeometry {
        guard floor > 0, ceiling > floor else {
            return make(value: value, target: ceiling, ceiling: ceiling)
        }
        let amount = max(value, 0)
        let fill: Double
        if amount <= floor {
            fill = amount / floor * rangeFloorAt
        } else if amount <= ceiling {
            fill = rangeFloorAt + (amount - floor) / (ceiling - floor) * (rangeCeilingAt - rangeFloorAt)
        } else {
            fill = min(1, rangeCeilingAt + (amount - ceiling) / ceiling * (1 - rangeCeilingAt))
        }
        return TargetBarGeometry(fill: fill, tick: nil, zone: rangeFloorAt...rangeCeilingAt,
                                 isOver: amount > ceiling)
    }

    static func make(value: Double, target: Double, minimum: Double) -> TargetBarGeometry {
        let base = make(value: value, target: target)
        guard target > 0, minimum > 0, minimum < target else { return base }
        let scale = target * headroom
        return TargetBarGeometry(fill: base.fill, tick: base.tick,
                                 zone: (minimum / scale)...(target / scale), isOver: false)
    }

    func filledSegments(of count: Int) -> Int {
        guard fill > 0 else { return 0 }
        return min(count, max(1, Int((fill * Double(count)).rounded())))
    }
}
