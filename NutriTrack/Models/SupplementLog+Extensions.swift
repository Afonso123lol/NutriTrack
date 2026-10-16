import CoreData

extension SupplementLog {
    static let doseRange = 0.5...10.0

    func setDoses(_ newDoses: Double, in ctx: NSManagedObjectContext) {
        let stepped = (newDoses * 2).rounded() / 2
        let clamped = min(max(stepped, Self.doseRange.lowerBound), Self.doseRange.upperBound)
        guard clamped != doses else { return }
        if doses > 0, let snapshot = snapshotNutrients,
           let data = try? JSONEncoder().encode(snapshot.scaled(by: clamped / doses)) {
            nutrientsJson = String(data: data, encoding: .utf8)
        }
        doses = clamped
        try? ctx.save()
        if let timestamp { EvaluationService.refreshClosedDay(containing: timestamp, in: ctx) }
    }

    static func log(template: SupplementTemplate, doses: Double, in ctx: NSManagedObjectContext) {
        let entry = SupplementLog(context: ctx)
        entry.id = UUID()
        entry.timestamp = Date()
        entry.doses = doses
        entry.templateID = template.id?.uuidString ?? ""
        entry.name = template.name
        if let data = try? JSONEncoder().encode(template.nutrientsScaled(by: doses)) {
            entry.nutrientsJson = String(data: data, encoding: .utf8)
        }
        try? ctx.save()
        EvaluationService.refreshClosedDay(containing: Date(), in: ctx)
    }

    var snapshotNutrients: NutritionAnalysis? {
        guard let nutrientsJson, let data = nutrientsJson.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(NutritionAnalysis.self, from: data)
    }
}
