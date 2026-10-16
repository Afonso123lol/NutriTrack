import XCTest
@testable import NutriTrack

@MainActor
final class SyncQueueTests: XCTestCase {

    private func tempDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("sync-\(UUID().uuidString)", isDirectory: true)
    }

    private let early = Date(timeIntervalSince1970: 1_000)
    private let late = Date(timeIntervalSince1970: 2_000)

    func testRepeatedChangesCollapseIntoOneKey() {
        let queue = SyncQueue(directory: tempDirectory())
        let key = SyncKey(entity: "WeightEntry", id: UUID())
        queue.apply(changed: [key], at: early)
        queue.apply(changed: [key], at: late)
        XCTAssertEqual(queue.state.records, [key: PendingRecord(deleted: false, changedAt: late)])
        XCTAssertEqual(queue.pendingCount, 1)
    }

    func testDeleteBecomesTombstoneAndDropsThePhoto() {
        let queue = SyncQueue(directory: tempDirectory())
        let key = SyncKey(entity: "FoodEntry", id: UUID())
        queue.apply(changed: [key], photos: [key.id], at: early)
        queue.apply(deleted: [key], at: late)
        XCTAssertEqual(queue.state.records[key], PendingRecord(deleted: true, changedAt: late))
        XCTAssertTrue(queue.state.photos.isEmpty)
    }

    func testChangeAfterDeleteStaysTombstone() {
        let queue = SyncQueue(directory: tempDirectory())
        let key = SyncKey(entity: "WeightEntry", id: UUID())
        queue.apply(deleted: [key], at: early)
        queue.apply(changed: [key], at: late)
        XCTAssertEqual(queue.state.records[key], PendingRecord(deleted: true, changedAt: early))
    }

    func testEventsGetIncreasingSequenceAcrossReload() {
        let dir = tempDirectory()
        let first = SyncQueue(directory: dir)
        first.appendEvent(kind: "app.launch", appState: "inactive")
        first.appendEvent(kind: "model.enqueued", appState: "active", details: ["jobID": "a"])
        let reloaded = SyncQueue(directory: dir)
        let third = reloaded.appendEvent(kind: "model.sent", appState: "active")
        XCTAssertEqual(reloaded.state.events.map(\.seq), [0, 1, 2])
        XCTAssertEqual(third.seq, 2)
        XCTAssertEqual(reloaded.state.deviceID, first.state.deviceID)
    }

    func testCompletedBatchRemovesItsKeysAndEvents() {
        let queue = SyncQueue(directory: tempDirectory())
        let sent = SyncKey(entity: "WeightEntry", id: UUID())
        let left = SyncKey(entity: "WeightEntry", id: UUID())
        queue.apply(changed: [sent, left], at: early)
        queue.appendEvent(kind: "app.launch", appState: "inactive")
        let manifest = queue.beginBatch(keys: [sent], lastEventSeq: 0)
        queue.appendEvent(kind: "model.sent", appState: "active")
        queue.completeBatch(id: manifest.id, at: late)
        XCTAssertEqual(Array(queue.state.records.keys), [left])
        XCTAssertEqual(queue.state.events.map(\.seq), [1])
        XCTAssertNil(queue.state.inFlightBatch)
        XCTAssertEqual(queue.state.lastSentAt, late)
        XCTAssertNil(queue.state.lastError)
    }

    func testKeyChangedDuringFlightStaysPending() {
        let queue = SyncQueue(directory: tempDirectory())
        let key = SyncKey(entity: "WeightEntry", id: UUID())
        queue.apply(changed: [key], at: early)
        let manifest = queue.beginBatch(keys: [key], lastEventSeq: nil)
        queue.apply(changed: [key], at: late)
        queue.completeBatch(id: manifest.id)
        XCTAssertEqual(queue.state.records[key], PendingRecord(deleted: false, changedAt: late))
    }

    func testFailedBatchKeepsEverythingAndRecordsTheError() {
        let queue = SyncQueue(directory: tempDirectory())
        let key = SyncKey(entity: "WeightEntry", id: UUID())
        queue.apply(changed: [key], at: early)
        queue.appendEvent(kind: "app.launch", appState: "inactive")
        let manifest = queue.beginBatch(keys: [key], lastEventSeq: 0)
        queue.failBatch(id: manifest.id, error: "HTTP 500")
        XCTAssertEqual(queue.state.records.count, 1)
        XCTAssertEqual(queue.state.events.count, 1)
        XCTAssertNil(queue.state.inFlightBatch)
        XCTAssertEqual(queue.state.lastError, "HTTP 500")
    }

    func testCompletingAnUnknownBatchDoesNothing() {
        let queue = SyncQueue(directory: tempDirectory())
        let key = SyncKey(entity: "WeightEntry", id: UUID())
        queue.apply(changed: [key], at: early)
        queue.completeBatch(id: UUID())
        XCTAssertEqual(queue.state.records.count, 1)
        XCTAssertNil(queue.state.lastSentAt)
    }

    func testPhotoCompletionAndBackfillFlagSurviveReload() {
        let dir = tempDirectory()
        let queue = SyncQueue(directory: dir)
        let photo = UUID()
        queue.apply(photos: [photo, UUID()], at: early)
        queue.completePhoto(photo, at: late)
        queue.markBackfillDone()
        let reloaded = SyncQueue(directory: dir)
        XCTAssertEqual(reloaded.state.photos.count, 1)
        XCTAssertTrue(reloaded.state.backfillDone)
        XCTAssertEqual(reloaded.state.lastSentAt, late)
        XCTAssertEqual(reloaded.pendingCount, 1)
    }

    func testAnUntouchedQueueWritesNoFile() {
        let dir = tempDirectory()
        _ = SyncQueue(directory: dir)
        XCTAssertFalse(FileManager.default.fileExists(atPath: dir.appendingPathComponent("queue.json").path))
    }
}
