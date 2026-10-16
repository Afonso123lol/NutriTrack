import XCTest
import CoreData
@testable import NutriTrack

@MainActor
final class SyncBatchBuilderTests: XCTestCase {

    private let base = Date(timeIntervalSince1970: 1_000)

    private func json(_ data: Data) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    func testBatchCarriesRecordsTombstonesAndEvents() throws {
        let ctx = Persistence(inMemory: true).container.viewContext
        let weight = WeightEntry(context: ctx)
        let weightID = UUID()
        weight.id = weightID
        weight.weightKg = 80.5
        try ctx.save()

        let live = SyncKey(entity: "WeightEntry", id: weightID)
        let tombstone = SyncKey(entity: "FoodEntry", id: UUID())
        let vanished = SyncKey(entity: "WeightEntry", id: UUID())
        var state = SyncQueueState()
        state.records[live] = PendingRecord(deleted: false, changedAt: base)
        state.records[tombstone] = PendingRecord(deleted: true, changedAt: base.addingTimeInterval(1))
        state.records[vanished] = PendingRecord(deleted: false, changedAt: base.addingTimeInterval(2))
        state.events = [SyncEvent(seq: 4, at: base, kind: "model.completed", appState: "background", details: ["durationS": "46.0"])]

        let batch = try XCTUnwrap(SyncBatchBuilder.build(state: state, context: ctx, sentAt: base))
        XCTAssertEqual(batch.keys, [live, tombstone, vanished])
        XCTAssertEqual(batch.lastEventSeq, 4)

        let body = try json(batch.body)
        XCTAssertEqual(body["deviceID"] as? String, state.deviceID.uuidString)
        let records = try XCTUnwrap(body["records"] as? [[String: Any]])
        XCTAssertEqual(records.count, 3)
        XCTAssertEqual(records[0]["entity"] as? String, "WeightEntry")
        XCTAssertEqual(records[0]["id"] as? String, weightID.uuidString)
        XCTAssertEqual(records[0]["deleted"] as? Bool, false)
        XCTAssertEqual(records[0]["updatedAt"] as? String, SyncRecordEncoder.timestamp(base))
        XCTAssertEqual((records[0]["payload"] as? [String: Any])?["weightKg"] as? Double, 80.5)
        XCTAssertEqual(records[1]["deleted"] as? Bool, true)
        XCTAssertNil(records[1]["payload"])
        XCTAssertEqual(records[2]["deleted"] as? Bool, true)

        let events = try XCTUnwrap(body["events"] as? [[String: Any]])
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0]["seq"] as? Int, 4)
        XCTAssertEqual(events[0]["kind"] as? String, "model.completed")
        XCTAssertEqual(events[0]["appState"] as? String, "background")
        XCTAssertEqual((events[0]["details"] as? [String: String])?["durationS"], "46.0")
    }

    func testRecordsAreCappedAndOldestGoFirst() throws {
        let ctx = Persistence(inMemory: true).container.viewContext
        var state = SyncQueueState()
        var oldest: SyncKey?
        for offset in 0..<600 {
            let key = SyncKey(entity: "WeightEntry", id: UUID())
            if offset == 0 { oldest = key }
            state.records[key] = PendingRecord(deleted: true, changedAt: base.addingTimeInterval(Double(offset)))
        }
        let batch = try XCTUnwrap(SyncBatchBuilder.build(state: state, context: ctx))
        XCTAssertEqual(batch.keys.count, SyncBatchBuilder.maxRecords)
        XCTAssertEqual(batch.keys.first, oldest)
    }

    func testBodyStaysAroundOneMegabyte() throws {
        let ctx = Persistence(inMemory: true).container.viewContext
        var state = SyncQueueState()
        for offset in 0..<15 {
            let entry = FoodEntry(context: ctx)
            let id = UUID()
            entry.id = id
            entry.note = String(repeating: "x", count: 100_000)
            state.records[SyncKey(entity: "FoodEntry", id: id)] = PendingRecord(deleted: false, changedAt: base.addingTimeInterval(Double(offset)))
        }
        try ctx.save()
        let batch = try XCTUnwrap(SyncBatchBuilder.build(state: state, context: ctx))
        XCTAssertGreaterThan(batch.keys.count, 0)
        XCTAssertLessThan(batch.keys.count, 15)
        XCTAssertLessThan(batch.body.count, 1_100_000)
    }

    func testNextPhotosSkipsInFlightAndFailedOnesWithinTheLimit() {
        let ids = (0..<6).map { _ in UUID() }.sorted { $0.uuidString < $1.uuidString }
        let chosen = SyncBatchBuilder.nextPhotos(pending: Set(ids), inFlight: [ids[0]], skipped: [ids[1]], limit: 4)
        XCTAssertEqual(chosen, [ids[2], ids[3], ids[4]])
        XCTAssertTrue(SyncBatchBuilder.nextPhotos(pending: Set(ids), inFlight: Set(ids.prefix(4)), skipped: [], limit: 4).isEmpty)
    }

    func testNothingPendingGivesNoBatch() {
        let ctx = Persistence(inMemory: true).container.viewContext
        XCTAssertNil(SyncBatchBuilder.build(state: SyncQueueState(), context: ctx))
    }

    func testSyncEventsAloneDoNotTriggerASend() {
        var state = SyncQueueState()
        XCTAssertFalse(SyncBatchBuilder.shouldSend(state))
        state.events = [SyncEvent(seq: 0, at: base, kind: "sync.batchSent", appState: "active", details: [:])]
        XCTAssertFalse(SyncBatchBuilder.shouldSend(state))
        state.events.append(SyncEvent(seq: 1, at: base, kind: "model.completed", appState: "active", details: [:]))
        XCTAssertTrue(SyncBatchBuilder.shouldSend(state))
        state.events = []
        state.records[SyncKey(entity: "WeightEntry", id: UUID())] = PendingRecord(deleted: false, changedAt: base)
        XCTAssertTrue(SyncBatchBuilder.shouldSend(state))
    }

    func testBatchMixesEntitiesAndTurnsMissingObjectsIntoTombstones() throws {
        let ctx = Persistence(inMemory: true).container.viewContext
        let meal = FoodEntry(context: ctx)
        meal.id = UUID()
        meal.dishName = "Eggs"
        let weight = WeightEntry(context: ctx)
        weight.id = UUID()
        weight.weightKg = 80
        try ctx.save()

        let missing = UUID()
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        var state = SyncQueueState()
        state.records[SyncKey(entity: "FoodEntry", id: meal.id!)] = PendingRecord(deleted: false, changedAt: base)
        state.records[SyncKey(entity: "WeightEntry", id: weight.id!)] = PendingRecord(deleted: false, changedAt: base.addingTimeInterval(1))
        state.records[SyncKey(entity: "FoodEntry", id: missing)] = PendingRecord(deleted: false, changedAt: base.addingTimeInterval(2))

        let batch = try XCTUnwrap(SyncBatchBuilder.build(state: state, context: ctx, sentAt: base))
        let envelope = try XCTUnwrap(JSONSerialization.jsonObject(with: batch.body) as? [String: Any])
        let records = try XCTUnwrap(envelope["records"] as? [[String: Any]])
        XCTAssertEqual(records.map { $0["id"] as? String }, [meal.id!.uuidString, weight.id!.uuidString, missing.uuidString])
        XCTAssertEqual(records.map { $0["deleted"] as? Bool }, [false, false, true])
        XCTAssertEqual((records[0]["payload"] as? [String: Any])?["dishName"] as? String, "Eggs")
        XCTAssertEqual((records[1]["payload"] as? [String: Any])?["weightKg"] as? Double, 80)
        XCTAssertNil(records[2]["payload"])
    }
}
