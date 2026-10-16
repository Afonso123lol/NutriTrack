import Foundation

enum SyncResponder {
    static func handleBatch(id: UUID, data: Data, statusCode: Int?, error: Error?, queue: SyncQueue, appState: String) {
        guard error == nil, let statusCode, (200..<300).contains(statusCode) else {
            let message = error?.localizedDescription ?? "HTTP \(statusCode ?? 0)"
            queue.failBatch(id: id, error: message)
            queue.appendEvent(kind: "sync.batchFailed", appState: appState, details: ["error": message])
            return
        }
        guard let manifest = queue.state.inFlightBatch, manifest.id == id else { return }
        let response = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        let rejected = response["rejected"] as? [[String: Any]] ?? []
        let rejectedEvents = response["rejectedEvents"] as? [[String: Any]] ?? []
        queue.completeBatch(id: id)
        for item in rejected {
            queue.appendEvent(kind: "sync.recordRejected", appState: appState, details: [
                "entity": item["entity"] as? String ?? "?",
                "id": item["id"] as? String ?? "?",
                "reason": item["reason"] as? String ?? "?"
            ])
        }
        for item in rejectedEvents {
            queue.appendEvent(kind: "sync.recordRejected", appState: appState, details: [
                "entity": "event",
                "id": (item["seq"] as? Int).map { String($0) } ?? "?",
                "reason": item["reason"] as? String ?? "?"
            ])
        }
        queue.appendEvent(kind: "sync.batchSent", appState: appState, details: [
            "records": String(manifest.records.count),
            "rejected": String(rejected.count + rejectedEvents.count)
        ])
    }

    static func handlePhoto(id: UUID, statusCode: Int?, error: Error?, queue: SyncQueue, appState: String) {
        if error == nil, let statusCode, (200..<300).contains(statusCode) {
            queue.completePhoto(id)
            return
        }
        if error == nil, statusCode == 413 || statusCode == 422 {
            queue.completePhoto(id, sent: false)
            queue.appendEvent(kind: "sync.recordRejected", appState: appState, details: [
                "entity": "photo", "id": id.uuidString, "reason": "HTTP \(statusCode ?? 0)"
            ])
            return
        }
        queue.recordError(error?.localizedDescription ?? "HTTP \(statusCode ?? 0)")
    }
}
