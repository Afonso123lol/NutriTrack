import Foundation

nonisolated enum SyncEntities {
    static let all = ["FoodEntry", "SupplementLog", "SupplementTemplate", "DailyCheckIn",
                      "WeightEntry", "DailyEvaluation", "UserProfile",
                      "TargetSnapshot", "TrainingProfile", "TrainingWeek", "PlannedSession",
                      "TrainingSession", "StrengthSet"]
    static let photoEntity = "FoodEntry"
}

nonisolated struct SyncKey: Codable, Hashable, Sendable {
    let entity: String
    let id: UUID
}

nonisolated struct PendingRecord: Codable, Equatable, Sendable {
    var deleted: Bool
    var changedAt: Date
}

nonisolated struct SyncEvent: Codable, Equatable, Sendable {
    let seq: Int
    let at: Date
    let kind: String
    let appState: String
    let details: [String: String]
}

nonisolated struct BatchManifest: Codable, Equatable, Sendable {
    let id: UUID
    let records: [SyncKey: Date]
    let lastEventSeq: Int?
}

nonisolated struct SyncQueueState: Codable, Equatable, Sendable {
    var deviceID = UUID()
    var records: [SyncKey: PendingRecord] = [:]
    var photos: Set<UUID> = []
    var events: [SyncEvent] = []
    var nextEventSeq = 0
    var inFlightBatch: BatchManifest?
    var lastSentAt: Date?
    var lastError: String?
    var backfillDone = false
}
