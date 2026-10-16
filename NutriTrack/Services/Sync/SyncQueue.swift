import Foundation
import Combine

final class SyncQueue: ObservableObject {
    @Published private(set) var state: SyncQueueState

    private let fileURL: URL

    init(directory: URL) {
        LocalStorage.prepareDirectory(directory)
        fileURL = directory.appendingPathComponent("queue.json")
        if let data = try? Data(contentsOf: fileURL),
           let saved = try? JSONDecoder().decode(SyncQueueState.self, from: data) {
            state = saved
        } else {
            state = SyncQueueState()
        }
    }

    var pendingCount: Int { state.records.count + state.photos.count }

    func apply(changed: [SyncKey] = [], photos: [UUID] = [], deleted: [SyncKey] = [], at date: Date = Date()) {
        mutate { state in
            for key in changed where state.records[key]?.deleted != true {
                state.records[key] = PendingRecord(deleted: false, changedAt: date)
            }
            state.photos.formUnion(photos)
            for key in deleted {
                state.records[key] = PendingRecord(deleted: true, changedAt: date)
                if key.entity == SyncEntities.photoEntity { state.photos.remove(key.id) }
            }
        }
    }

    @discardableResult
    func appendEvent(kind: String, appState: String, details: [String: String] = [:], at date: Date = Date()) -> SyncEvent {
        let event = SyncEvent(seq: state.nextEventSeq, at: date, kind: kind, appState: appState, details: details)
        mutate { state in
            state.nextEventSeq += 1
            state.events.append(event)
        }
        return event
    }

    func beginBatch(keys: [SyncKey], lastEventSeq: Int?) -> BatchManifest {
        var records: [SyncKey: Date] = [:]
        for key in keys {
            if let pending = state.records[key] { records[key] = pending.changedAt }
        }
        let manifest = BatchManifest(id: UUID(), records: records, lastEventSeq: lastEventSeq)
        mutate { $0.inFlightBatch = manifest }
        return manifest
    }

    func completeBatch(id: UUID, at date: Date = Date()) {
        guard let manifest = state.inFlightBatch, manifest.id == id else { return }
        mutate { state in
            for (key, changedAt) in manifest.records where state.records[key]?.changedAt == changedAt {
                state.records[key] = nil
            }
            if let last = manifest.lastEventSeq {
                state.events.removeAll { $0.seq <= last }
            }
            state.inFlightBatch = nil
            state.lastSentAt = date
            state.lastError = nil
        }
    }

    func failBatch(id: UUID, error: String?) {
        guard state.inFlightBatch?.id == id else { return }
        mutate { state in
            state.inFlightBatch = nil
            if let error { state.lastError = error }
        }
    }

    func completePhoto(_ id: UUID, sent: Bool = true, at date: Date = Date()) {
        mutate { state in
            state.photos.remove(id)
            if sent {
                state.lastSentAt = date
                state.lastError = nil
            }
        }
    }

    func recordError(_ message: String) {
        mutate { $0.lastError = message }
    }

    func markBackfillDone() {
        mutate { $0.backfillDone = true }
    }

    private func mutate(_ change: (inout SyncQueueState) -> Void) {
        var next = state
        change(&next)
        state = next
        guard let data = try? JSONEncoder().encode(next) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
