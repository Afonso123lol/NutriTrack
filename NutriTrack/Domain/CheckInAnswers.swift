import Foundation

nonisolated struct CheckInAnswers: Equatable, Sendable {
    var energy = 0
    var quality = 0
    var soreness = 0
    var stress = 0
    var sleepHours = 7.5
    var wakeTime: Date
    var isSick = false
    var hasPain = false

    var isComplete: Bool {
        [energy, quality, soreness, stress].allSatisfy { (1...5).contains($0) }
    }
}
