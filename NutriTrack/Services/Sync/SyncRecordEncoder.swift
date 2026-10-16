import CoreData

enum SyncRecordEncoder {
    nonisolated static func timestamp(_ date: Date) -> String {
        Date.ISO8601FormatStyle(includingFractionalSeconds: true).format(date)
    }

    static func payload(for object: NSManagedObject) -> [String: Any] {
        var payload: [String: Any] = [:]
        for (name, attribute) in object.entity.attributesByName where attribute.attributeType != .binaryDataAttributeType {
            guard let value = object.value(forKey: name) else { continue }
            switch value {
            case let date as Date:
                payload[name] = timestamp(date)
            case let uuid as UUID:
                payload[name] = uuid.uuidString
            case let string as String:
                payload[name] = string
            case let number as NSNumber:
                if attribute.attributeType == .booleanAttributeType {
                    payload[name] = number.boolValue
                } else {
                    payload[name] = number.doubleValue.isFinite ? number : NSNull()
                }
            default:
                continue
            }
        }
        if object.entity.name == SyncEntities.photoEntity {
            payload["hasPhoto"] = object.value(forKey: "photoData") != nil
        }
        return payload
    }
}
