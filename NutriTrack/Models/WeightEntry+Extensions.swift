import CoreData

extension WeightEntry {
    static func log(weightKg: Double, in ctx: NSManagedObjectContext) {
        let e = WeightEntry(context: ctx)
        e.id = UUID()
        e.date = Date()
        e.weightKg = weightKg
        try? ctx.save()
    }
}
