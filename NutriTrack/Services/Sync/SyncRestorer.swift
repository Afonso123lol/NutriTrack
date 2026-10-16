import CoreData
import UIKit
import Combine

struct RestoreRecord {
    let entity: String
    let id: UUID
    let updatedAt: String
    let payload: [String: Any]
}

enum RestoreError: LocalizedError, Equatable {
    case server(Int)
    case unreadable

    var errorDescription: String? {
        switch self {
        case .server(let status): return "Your server answered with an error (\(status))."
        case .unreadable: return "Your server sent an answer the app could not read."
        }
    }
}

struct SyncRestoreClient {
    static let pageSize = 200

    let config: SyncConfig
    var fetch: (URLRequest) async throws -> (Data, URLResponse) = { try await URLSession.shared.data(for: $0) }

    func allRecords() async throws -> [RestoreRecord] {
        var records: [RestoreRecord] = []
        var cursor: Int? = 0
        while let after = cursor {
            var request = config.request(path: "v1/records", method: "GET", contentType: "application/json")
            request.url = request.url?.appending(queryItems: [URLQueryItem(name: "after", value: String(after)),
                                                              URLQueryItem(name: "limit", value: String(Self.pageSize))])
            request.timeoutInterval = 30
            let (data, response) = try await fetch(request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard status == 200 else { throw RestoreError.server(status) }
            let page = try SyncRestorer.parsePage(data)
            records += page.records
            cursor = page.next
        }
        return records
    }

    func photo(_ id: UUID) async -> Data? {
        var request = config.request(path: "v1/photos/\(id.uuidString)", method: "GET", contentType: "image/jpeg")
        request.timeoutInterval = 30
        guard let (data, response) = try? await fetch(request),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return data
    }
}

enum SyncRestorer {
    static let singletons: Set<String> = ["UserProfile", "TrainingProfile"]

    static func parsePage(_ data: Data) throws -> (records: [RestoreRecord], next: Int?) {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = object["records"] as? [[String: Any]] else { throw RestoreError.unreadable }
        let records = items.compactMap { item -> RestoreRecord? in
            guard let entity = item["entity"] as? String,
                  let id = (item["id"] as? String).flatMap(UUID.init(uuidString:)),
                  let updatedAt = item["updatedAt"] as? String,
                  let payload = item["payload"] as? [String: Any] else { return nil }
            return RestoreRecord(entity: entity, id: id, updatedAt: updatedAt, payload: payload)
        }
        return (records, object["next"] as? Int)
    }

    @discardableResult
    static func importRecords(_ records: [RestoreRecord], into ctx: NSManagedObjectContext) -> [UUID] {
        var photos: [UUID] = []
        for entity in SyncEntities.all {
            var incoming = records.filter { $0.entity == entity }
            if singletons.contains(entity) {
                let request = NSFetchRequest<NSManagedObject>(entityName: entity)
                if ((try? ctx.count(for: request)) ?? 0) > 0 { continue }
                incoming = incoming.max { $0.updatedAt < $1.updatedAt }.map { [$0] } ?? []
            }
            var known = existingIDs(of: entity, in: ctx)
            for record in incoming where !known.contains(record.id) {
                let object = NSEntityDescription.insertNewObject(forEntityName: entity, into: ctx)
                decode(record.payload, into: object)
                object.setValue(record.id, forKey: "id")
                known.insert(record.id)
                if entity == SyncEntities.photoEntity, record.payload["hasPhoto"] as? Bool == true {
                    photos.append(record.id)
                }
            }
        }
        return photos
    }

    static func decode(_ payload: [String: Any], into object: NSManagedObject) {
        for (name, attribute) in object.entity.attributesByName {
            guard let raw = payload[name], !(raw is NSNull) else { continue }
            switch attribute.attributeType {
            case .dateAttributeType:
                if let text = raw as? String, let date = date(from: text) { object.setValue(date, forKey: name) }
            case .UUIDAttributeType:
                if let uuid = (raw as? String).flatMap(UUID.init(uuidString:)) { object.setValue(uuid, forKey: name) }
            case .stringAttributeType:
                if let text = raw as? String { object.setValue(text, forKey: name) }
            case .booleanAttributeType, .integer16AttributeType, .integer32AttributeType, .integer64AttributeType,
                 .doubleAttributeType, .floatAttributeType:
                if let number = raw as? NSNumber { object.setValue(number, forKey: name) }
            default:
                continue
            }
        }
    }

    static func attachPhoto(_ data: Data, to id: UUID, in ctx: NSManagedObjectContext) {
        let request = FoodEntry.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        guard let entry = try? ctx.fetch(request).first, let image = UIImage(data: data) else { return }
        entry.photoData = data
        entry.thumbnailData = GeminiService.analysisJPEG(from: image, maxDimension: FoodEntry.thumbnailDimension)
    }

    private static func date(from text: String) -> Date? {
        (try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(text))
            ?? (try? Date.ISO8601FormatStyle().parse(text))
    }

    private static func existingIDs(of entity: String, in ctx: NSManagedObjectContext) -> Set<UUID> {
        let request = NSFetchRequest<NSManagedObject>(entityName: entity)
        return Set(((try? ctx.fetch(request)) ?? []).compactMap { $0.value(forKey: "id") as? UUID })
    }
}

final class RestoreModel: ObservableObject {
    enum Phase: Equatable {
        case idle
        case working(String)
        case failed(String)
    }

    @Published var phase: Phase = .idle

    var isWorking: Bool {
        if case .working = phase { return true }
        return false
    }

    func run(engine: SyncEngine, in ctx: NSManagedObjectContext) async {
        guard !isWorking else { return }
        phase = .working("Looking for your data")
        let client = SyncRestoreClient(config: engine.config)
        do {
            let records = try await client.allRecords()
            guard records.contains(where: { $0.entity == "UserProfile" }) else {
                phase = .failed("No saved profile was found on your server.")
                return
            }
            let photos = SyncRestorer.importRecords(records, into: ctx)
            engine.saveWithoutQueueing(ctx)
            for (index, id) in photos.enumerated() {
                phase = .working("Bringing back photos (\(index + 1) of \(photos.count))")
                if let data = await client.photo(id) {
                    SyncRestorer.attachPhoto(data, to: id, in: ctx)
                    engine.saveWithoutQueueing(ctx)
                }
            }
            engine.log("restore.completed", ["records": String(records.count), "photos": String(photos.count)])
            phase = .idle
        } catch let error as RestoreError {
            phase = .failed(error.localizedDescription)
        } catch {
            phase = .failed("Could not reach your server. Check that Tailscale is on and try again.")
        }
    }
}
