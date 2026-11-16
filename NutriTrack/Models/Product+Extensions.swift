import CoreData

extension Product {
    static func find(ean: String, in ctx: NSManagedObjectContext) -> Product? {
        let request = Product.fetchRequest()
        request.predicate = NSPredicate(format: "ean == %@", ean)
        request.fetchLimit = 1
        return try? ctx.fetch(request).first
    }

    @discardableResult
    static func store(_ info: ProductInfo, source: String, now: Date = Date(), in ctx: NSManagedObjectContext) -> Product {
        let product = find(ean: info.ean, in: ctx) ?? {
            let created = Product(context: ctx)
            created.id = UUID()
            created.ean = info.ean
            return created
        }()
        product.name = info.name
        product.brand = info.brand
        product.source = source
        product.caloriesPer100 = info.caloriesPer100
        product.proteinPer100 = info.proteinPer100
        product.carbsPer100 = info.carbsPer100
        product.fatPer100 = info.fatPer100
        product.fiberPer100 = info.fiberPer100
        product.sugarPer100 = info.sugarPer100
        product.saturatedFatPer100 = info.saturatedFatPer100
        product.sodiumMgPer100 = info.sodiumMgPer100
        product.potassiumMgPer100 = info.potassiumMgPer100
        product.calciumMgPer100 = info.calciumMgPer100
        product.servingG = info.servingG ?? 0
        product.packageG = info.packageG ?? 0
        product.fetchedAt = now
        try? ctx.save()
        return product
    }

    var info: ProductInfo {
        ProductInfo(ean: ean ?? "", name: name ?? "Product", brand: brand,
                    caloriesPer100: caloriesPer100, proteinPer100: proteinPer100, carbsPer100: carbsPer100,
                    fatPer100: fatPer100, fiberPer100: fiberPer100, sugarPer100: sugarPer100,
                    saturatedFatPer100: saturatedFatPer100, sodiumMgPer100: sodiumMgPer100,
                    potassiumMgPer100: potassiumMgPer100, calciumMgPer100: calciumMgPer100,
                    servingG: servingG > 0 ? servingG : nil, packageG: packageG > 0 ? packageG : nil)
    }
}

extension FoodEntry {
    static let labelSource = "label"

    @discardableResult
    static func create(from product: Product, portion: ProductPortion, timestamp: Date = Date(),
                       in ctx: NSManagedObjectContext) -> FoodEntry {
        let e = FoodEntry(context: ctx)
        e.id = UUID()
        e.timestamp = timestamp
        e.apply(product.info.analysis(grams: portion.grams))
        e.source = labelSource
        e.productEAN = product.ean
        e.grams = portion.grams
        e.portionLabel = portion.label
        product.lastUsedAt = timestamp
        product.lastGrams = portion.grams
        product.useCount += 1
        try? ctx.save()
        EvaluationService.refreshClosedDay(containing: timestamp, in: ctx)
        return e
    }
}
