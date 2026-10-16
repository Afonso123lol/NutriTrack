import XCTest
@testable import NutriTrack

@MainActor
final class SyncResponderTests: XCTestCase {

    private func makeQueue() -> SyncQueue {
        SyncQueue(directory: FileManager.default.temporaryDirectory
            .appendingPathComponent("responder-\(UUID().uuidString)", isDirectory: true))
    }

    private func startBatch(_ queue: SyncQueue) -> (BatchManifest, SyncKey) {
        let key = SyncKey(entity: "WeightEntry", id: UUID())
        queue.apply(changed: [key])
        queue.appendEvent(kind: "app.launch", appState: "inactive")
        return (queue.beginBatch(keys: [key], lastEventSeq: 0), key)
    }

    private func response(_ object: [String: Any]) -> Data {
        try! JSONSerialization.data(withJSONObject: object)
    }

    func testSuccessfulBatchCompletesAndLogsIt() {
        let queue = makeQueue()
        let (manifest, _) = startBatch(queue)
        let body = response(["accepted": 1, "rejected": [], "eventsAccepted": 1, "rejectedEvents": []])
        SyncResponder.handleBatch(id: manifest.id, data: body, statusCode: 200, error: nil, queue: queue, appState: "active")
        XCTAssertTrue(queue.state.records.isEmpty)
        XCTAssertNil(queue.state.inFlightBatch)
        XCTAssertNotNil(queue.state.lastSentAt)
        XCTAssertEqual(queue.state.events.map(\.kind), ["sync.batchSent"])
        XCTAssertEqual(queue.state.events.first?.details["records"], "1")
    }

    func testRejectedRecordsAndEventsAreLogged() {
        let queue = makeQueue()
        let (manifest, key) = startBatch(queue)
        let body = response([
            "accepted": 0,
            "rejected": [["entity": "WeightEntry", "id": key.id.uuidString, "reason": "invalid updatedAt"]],
            "eventsAccepted": 0,
            "rejectedEvents": [["seq": 0, "reason": "invalid kind"]]
        ])
        SyncResponder.handleBatch(id: manifest.id, data: body, statusCode: 200, error: nil, queue: queue, appState: "background")
        XCTAssertTrue(queue.state.records.isEmpty)
        XCTAssertEqual(queue.state.events.map(\.kind), ["sync.recordRejected", "sync.recordRejected", "sync.batchSent"])
        XCTAssertEqual(queue.state.events[0].details, ["entity": "WeightEntry", "id": key.id.uuidString, "reason": "invalid updatedAt"])
        XCTAssertEqual(queue.state.events[1].details, ["entity": "event", "id": "0", "reason": "invalid kind"])
        XCTAssertEqual(queue.state.events[2].appState, "background")
    }

    func testServerErrorKeepsTheQueue() {
        let queue = makeQueue()
        let (manifest, _) = startBatch(queue)
        SyncResponder.handleBatch(id: manifest.id, data: Data(), statusCode: 500, error: nil, queue: queue, appState: "active")
        XCTAssertEqual(queue.state.records.count, 1)
        XCTAssertNil(queue.state.inFlightBatch)
        XCTAssertEqual(queue.state.lastError, "HTTP 500")
        XCTAssertEqual(queue.state.events.map(\.kind), ["app.launch", "sync.batchFailed"])
    }

    func testNetworkErrorKeepsTheQueue() {
        let queue = makeQueue()
        let (manifest, _) = startBatch(queue)
        SyncResponder.handleBatch(id: manifest.id, data: Data(), statusCode: nil, error: URLError(.cannotFindHost),
                                  queue: queue, appState: "active")
        XCTAssertEqual(queue.state.records.count, 1)
        XCTAssertNotNil(queue.state.lastError)
        XCTAssertEqual(queue.state.events.last?.kind, "sync.batchFailed")
    }

    func testPhotoSuccessRemovesThePhoto() {
        let queue = makeQueue()
        let id = UUID()
        queue.apply(photos: [id])
        SyncResponder.handlePhoto(id: id, statusCode: 204, error: nil, queue: queue, appState: "active")
        XCTAssertTrue(queue.state.photos.isEmpty)
        XCTAssertNotNil(queue.state.lastSentAt)
    }

    func testRejectedPhotoIsDroppedAndLogged() {
        let queue = makeQueue()
        let id = UUID()
        queue.apply(photos: [id])
        SyncResponder.handlePhoto(id: id, statusCode: 422, error: nil, queue: queue, appState: "active")
        XCTAssertTrue(queue.state.photos.isEmpty)
        XCTAssertNil(queue.state.lastSentAt)
        XCTAssertEqual(queue.state.events.map(\.kind), ["sync.recordRejected"])
        XCTAssertEqual(queue.state.events.first?.details["entity"], "photo")
    }

    func testPhotoServerErrorKeepsThePhoto() {
        let queue = makeQueue()
        let id = UUID()
        queue.apply(photos: [id])
        SyncResponder.handlePhoto(id: id, statusCode: 503, error: nil, queue: queue, appState: "active")
        XCTAssertEqual(queue.state.photos, [id])
        XCTAssertEqual(queue.state.lastError, "HTTP 503")
    }
}
