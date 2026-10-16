import CoreData

struct SyncBatch {
    let keys: [SyncKey]
    let lastEventSeq: Int?
    let body: Data
}

enum SyncBatchBuilder {
    nonisolated static let maxRecords = 500
    nonisolated static let maxEvents = 500
    nonisolated static let maxBodyBytes = 1_000_000

    nonisolated static func shouldSend(_ state: SyncQueueState) -> Bool {
        !state.records.isEmpty || state.events.contains { !$0.kind.hasPrefix("sync.") }
    }

    nonisolated static func nextPhotos(pending: Set<UUID>, inFlight: Set<UUID>, skipped: Set<UUID>, limit: Int) -> [UUID] {
        let slots = max(0, limit - inFlight.count)
        let candidates = pending.subtracting(inFlight).subtracting(skipped).sorted { $0.uuidString < $1.uuidString }
        return Array(candidates.prefix(slots))
    }

    static func build(state: SyncQueueState, context: NSManagedObjectContext, sentAt: Date = Date()) -> SyncBatch? {
        let ordered = state.records.sorted {
            ($0.value.changedAt, $0.key.id.uuidString) < ($1.value.changedAt, $1.key.id.uuidString)
        }.prefix(maxRecords)
        let objects = fetchObjects(for: ordered.filter { !$0.value.deleted }.map(\.key), in: context)
        var keys: [SyncKey] = []
        var records: [[String: Any]] = []
        var bytes = 0
        for (key, pending) in ordered {
            let item = record(for: key, pending: pending, object: objects[key])
            let size = (try? JSONSerialization.data(withJSONObject: item))?.count ?? 0
            if !keys.isEmpty && bytes + size > maxBodyBytes { break }
            keys.append(key)
            records.append(item)
            bytes += size
        }
        let events = Array(state.events.prefix(maxEvents))
        guard !keys.isEmpty || !events.isEmpty else { return nil }
        let envelope: [String: Any] = [
            "deviceID": state.deviceID.uuidString,
            "sentAt": SyncRecordEncoder.timestamp(sentAt),
            "records": records,
            "events": events.map { event in
                ["seq": event.seq, "at": SyncRecordEncoder.timestamp(event.at), "kind": event.kind,
                 "appState": event.appState, "details": event.details] as [String: Any]
            }
        ]
        guard let body = try? JSONSerialization.data(withJSONObject: envelope) else { return nil }
        return SyncBatch(keys: keys, lastEventSeq: events.last?.seq, body: body)
    }

    static func record(for key: SyncKey, pending: PendingRecord, object: NSManagedObject?) -> [String: Any] {
        var item: [String: Any] = [
            "entity": key.entity,
            "id": key.id.uuidString,
            "updatedAt": SyncRecordEncoder.timestamp(pending.changedAt)
        ]
        if !pending.deleted, let object {
            item["deleted"] = false
            item["payload"] = SyncRecordEncoder.payload(for: object)
        } else {
            item["deleted"] = true
        }
        return item
    }

    static func fetchObjects(for keys: [SyncKey], in context: NSManagedObjectContext) -> [SyncKey: NSManagedObject] {
        var result: [SyncKey: NSManagedObject] = [:]
        for (entity, group) in Dictionary(grouping: keys, by: \.entity) {
            let request = NSFetchRequest<NSManagedObject>(entityName: entity)
            request.predicate = NSPredicate(format: "id IN %@", group.map(\.id))
            for object in (try? context.fetch(request)) ?? [] {
                if let id = object.value(forKey: "id") as? UUID { result[SyncKey(entity: entity, id: id)] = object }
            }
        }
        return result
    }

    static func fetch(_ key: SyncKey, in context: NSManagedObjectContext) -> NSManagedObject? {
        let request = NSFetchRequest<NSManagedObject>(entityName: key.entity)
        request.predicate = NSPredicate(format: "id == %@", key.id as CVarArg)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }
}
