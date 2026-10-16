import CoreData
import UIKit

extension FoodEntry {
    private static let fields: [(ReferenceWritableKeyPath<FoodEntry, Double>, WritableKeyPath<NutritionAnalysis, Double>)] = [
        (\.calories, \.calories), (\.proteinG, \.proteinG), (\.carbsG, \.carbsG), (\.fatG, \.fatG),
        (\.saturatedFatG, \.saturatedFatG), (\.omega3G, \.omega3G), (\.fiberG, \.fiberG), (\.sugarG, \.sugarG),
        (\.sodiumMg, \.sodiumMg), (\.potassiumMg, \.potassiumMg), (\.calciumMg, \.calciumMg), (\.ironMg, \.ironMg),
        (\.zincMg, \.zincMg), (\.magnesiumMg, \.magnesiumMg), (\.phosphorusMg, \.phosphorusMg),
        (\.seleniumUg, \.seleniumUg), (\.copperUg, \.copperUg), (\.vitaminCMg, \.vitaminCMg),
        (\.vitaminDUg, \.vitaminDUg), (\.vitaminEMg, \.vitaminEMg), (\.vitaminKUg, \.vitaminKUg),
        (\.vitaminB1Mg, \.vitaminB1Mg), (\.vitaminB2Mg, \.vitaminB2Mg), (\.vitaminB3Mg, \.vitaminB3Mg),
        (\.vitaminB5Mg, \.vitaminB5Mg), (\.vitaminB6Mg, \.vitaminB6Mg), (\.vitaminB12Ug, \.vitaminB12Ug),
        (\.folateUg, \.folateUg)
    ]

    private static let optionalFields: [(ReferenceWritableKeyPath<FoodEntry, Double>, WritableKeyPath<NutritionAnalysis, Double?>)] = [
        (\.monounsaturatedFatG, \.monounsaturatedFatG), (\.polyunsaturatedFatG, \.polyunsaturatedFatG),
        (\.transFatG, \.transFatG), (\.vitaminAUg, \.vitaminAUg), (\.alcoholG, \.alcoholG)
    ]

    static let thumbnailDimension: CGFloat = 216
    static let historyPageDays = 30

    @discardableResult
    static func create(from analysis: NutritionAnalysis, image: UIImage?, note: String?,
                       timestamp: Date = Date(), wasEdited: Bool = false,
                       in ctx: NSManagedObjectContext) -> FoodEntry {
        let e = FoodEntry(context: ctx)
        e.id = UUID()
        e.timestamp = timestamp
        e.aiComment = analysis.comment
        e.note = note
        if let image {
            e.photoData = GeminiService.analysisJPEG(from: image)
            e.thumbnailData = GeminiService.analysisJPEG(from: image, maxDimension: thumbnailDimension)
        }
        e.wasEdited = wasEdited
        e.apply(analysis)
        try? ctx.save()
        EvaluationService.refreshClosedDay(containing: timestamp, in: ctx)
        return e
    }

    @discardableResult
    static func logAgain(_ source: FoodEntry, multiplier: Double, now: Date = Date(),
                         in ctx: NSManagedObjectContext) -> FoodEntry {
        let e = FoodEntry(context: ctx)
        e.id = UUID()
        e.timestamp = now
        e.aiComment = source.aiComment
        e.note = source.note
        e.photoData = source.photoData
        e.thumbnailData = source.thumbnailData
        e.sourceEntryID = source.id
        e.wasEdited = source.wasEdited
        e.apply(NutrientValidator.validate(source.analysis.scaled(by: multiplier), keepCalories: true))
        try? ctx.save()
        EvaluationService.refreshClosedDay(containing: now, in: ctx)
        return e
    }

    func applyEdit(_ edited: NutritionAnalysis, in ctx: NSManagedObjectContext) {
        apply(edited)
        wasEdited = true
        try? ctx.save()
        if let timestamp { EvaluationService.refreshClosedDay(containing: timestamp, in: ctx) }
    }

    func changeTime(to newTime: Date, in ctx: NSManagedObjectContext) {
        let previous = timestamp
        timestamp = newTime
        try? ctx.save()
        if let previous { EvaluationService.refreshClosedDay(containing: previous, in: ctx) }
        EvaluationService.refreshClosedDay(containing: newTime, in: ctx)
    }

    func remove(from ctx: NSManagedObjectContext) {
        let day = timestamp
        ctx.delete(self)
        try? ctx.save()
        if let day { EvaluationService.refreshClosedDay(containing: day, in: ctx) }
    }

    static func backfillThumbnails(in ctx: NSManagedObjectContext, batchSize: Int = 20) async {
        let request = FoodEntry.fetchRequest()
        request.predicate = NSPredicate(format: "thumbnailData == nil AND photoData != nil")
        guard let entries = try? ctx.fetch(request), !entries.isEmpty else { return }
        for (index, entry) in entries.enumerated() {
            autoreleasepool {
                if let data = entry.photoData, let image = UIImage(data: data) {
                    entry.thumbnailData = GeminiService.analysisJPEG(from: image, maxDimension: thumbnailDimension)
                }
            }
            if (index + 1) % batchSize == 0 {
                try? ctx.save()
                await Task.yield()
            }
        }
        try? ctx.save()
    }

    static func historyCutoff(days: Int, now: Date = Date()) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: Calendar.current.startOfDay(for: now)) ?? now
    }

    var analysis: NutritionAnalysis {
        var result = NutritionAnalysis.empty
        result.dishName = dishName ?? "Meal"
        result.comment = aiComment
        for (entryField, field) in Self.fields { result[keyPath: field] = self[keyPath: entryField] }
        for (entryField, field) in Self.optionalFields { result[keyPath: field] = self[keyPath: entryField] }
        return result
    }

    func apply(_ analysis: NutritionAnalysis) {
        dishName = analysis.dishName
        for (entryField, field) in Self.fields { self[keyPath: entryField] = analysis[keyPath: field] }
        for (entryField, field) in Self.optionalFields { self[keyPath: entryField] = analysis[keyPath: field] ?? 0 }
    }
}
