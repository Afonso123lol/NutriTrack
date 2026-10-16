import CoreData

enum SyncBackfill {
    static func runIfNeeded(context: NSManagedObjectContext, queue: SyncQueue) -> Bool {
        guard !queue.state.backfillDone else { return false }
        var records: [SyncKey] = []
        for entity in SyncEntities.all {
            records += ids(of: entity, predicate: nil, in: context).map { SyncKey(entity: entity, id: $0) }
        }
        let photos = ids(of: SyncEntities.photoEntity, predicate: NSPredicate(format: "photoData != nil"), in: context)
        queue.apply(changed: records, photos: photos)
        queue.markBackfillDone()
        return true
    }

    private static func ids(of entity: String, predicate: NSPredicate?, in context: NSManagedObjectContext) -> [UUID] {
        let request = NSFetchRequest<NSDictionary>(entityName: entity)
        request.resultType = .dictionaryResultType
        request.propertiesToFetch = ["id"]
        request.predicate = predicate
        return ((try? context.fetch(request)) ?? []).compactMap { $0["id"] as? UUID }
    }
}
