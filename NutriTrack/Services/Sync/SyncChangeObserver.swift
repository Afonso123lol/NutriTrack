import CoreData

final class SyncChangeObserver: NSObject {
    private let queue: SyncQueue
    private let onChange: () -> Void
    private var deletions: [NSManagedObjectID: SyncKey] = [:]
    var isSuppressed = false

    init(context: NSManagedObjectContext, queue: SyncQueue, onChange: @escaping () -> Void) {
        self.queue = queue
        self.onChange = onChange
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(contextWillSave(_:)),
                                               name: NSManagedObjectContext.willSaveObjectsNotification, object: context)
        NotificationCenter.default.addObserver(self, selector: #selector(contextDidSave(_:)),
                                               name: NSManagedObjectContext.didSaveObjectsNotification, object: context)
    }

    static func key(for object: NSManagedObject) -> SyncKey? {
        guard let entity = object.entity.name, SyncEntities.all.contains(entity),
              let id = object.value(forKey: "id") as? UUID else { return nil }
        return SyncKey(entity: entity, id: id)
    }

    @objc private func contextWillSave(_ notification: Notification) {
        guard let context = notification.object as? NSManagedObjectContext else { return }
        for object in context.deletedObjects {
            if let key = Self.key(for: object) { deletions[object.objectID] = key }
        }
    }

    @objc private func contextDidSave(_ notification: Notification) {
        if isSuppressed {
            deletions.removeAll()
            return
        }
        let info = notification.userInfo ?? [:]
        let inserted = info[NSInsertedObjectsKey] as? Set<NSManagedObject> ?? []
        let updated = info[NSUpdatedObjectsKey] as? Set<NSManagedObject> ?? []
        let deleted = info[NSDeletedObjectsKey] as? Set<NSManagedObject> ?? []
        let changed = inserted.union(updated).compactMap { Self.key(for: $0) }
        let photos = inserted
            .filter { $0.entity.name == SyncEntities.photoEntity && $0.value(forKey: "photoData") != nil }
            .compactMap { Self.key(for: $0)?.id }
        let removed = deleted.compactMap { deletions.removeValue(forKey: $0.objectID) }
        guard !changed.isEmpty || !removed.isEmpty else { return }
        queue.apply(changed: changed, photos: photos, deleted: removed)
        onChange()
    }
}
