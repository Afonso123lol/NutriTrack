import Foundation

nonisolated struct ProductInfo: Equatable, Sendable {
    let ean: String
    let name: String
    let brand: String?
    let caloriesPer100: Double
    let proteinPer100: Double
    let carbsPer100: Double
    let fatPer100: Double
    let fiberPer100: Double
    let sugarPer100: Double
    let saturatedFatPer100: Double
    let sodiumMgPer100: Double
    let potassiumMgPer100: Double
    let calciumMgPer100: Double
    let servingG: Double?
    let packageG: Double?

    var displayName: String {
        guard let brand, !brand.isEmpty, !name.localizedCaseInsensitiveContains(brand) else { return name }
        return "\(name) · \(brand)"
    }

    func analysis(grams: Double) -> NutritionAnalysis {
        let factor = max(grams, 0) / 100
        var result = NutritionAnalysis.empty
        result.dishName = displayName
        result.calories = caloriesPer100 * factor
        result.proteinG = proteinPer100 * factor
        result.carbsG = carbsPer100 * factor
        result.fatG = fatPer100 * factor
        result.fiberG = fiberPer100 * factor
        result.sugarG = sugarPer100 * factor
        result.saturatedFatG = saturatedFatPer100 * factor
        result.sodiumMg = sodiumMgPer100 * factor
        result.potassiumMg = potassiumMgPer100 * factor
        result.calciumMg = calciumMgPer100 * factor
        return result
    }
}

nonisolated struct ProductPortion: Equatable, Sendable, Identifiable {
    let label: String
    let grams: Double
    var id: String { label }

    static func choices(for product: ProductInfo, lastGrams: Double?) -> [ProductPortion] {
        var portions: [ProductPortion] = []
        if let package = product.packageG, package > 0 {
            portions.append(ProductPortion(label: "1 pack (\(Self.grams(package)) g)", grams: package))
        }
        if let serving = product.servingG, serving > 0, serving != product.packageG {
            portions.append(ProductPortion(label: "1 serving (\(Self.grams(serving)) g)", grams: serving))
        }
        if let last = lastGrams, last > 0, !portions.contains(where: { $0.grams == last }), last != 100 {
            portions.insert(ProductPortion(label: "Last time (\(Self.grams(last)) g)", grams: last), at: 0)
        }
        portions.append(ProductPortion(label: "100 g", grams: 100))
        return portions
    }

    static func grams(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(format: "%.1f", value)
    }
}

nonisolated enum OpenFoodFactsError: Error, Equatable {
    case invalidResponse
}

nonisolated enum OpenFoodFacts {
    static let userAgent = "NutriTrack/1.0 (personal iOS app)"
    static let attribution = "Data from Open Food Facts (ODbL)"
    static let siteURL = URL(string: "https://world.openfoodfacts.org")!
    static let fields = "code,product_name,product_name_pt,product_name_en,brands,quantity,product_quantity,product_quantity_unit,serving_quantity,nutriments"

    static func productURL(ean: String) -> URL? {
        guard isValidBarcode(ean) else { return nil }
        var components = URLComponents(string: "https://world.openfoodfacts.org/api/v2/product/\(ean).json")
        components?.queryItems = [URLQueryItem(name: "fields", value: fields)]
        return components?.url
    }

    static func pageURL(ean: String) -> URL? {
        guard isValidBarcode(ean) else { return nil }
        return URL(string: "https://world.openfoodfacts.org/product/\(ean)")
    }

    static func isValidBarcode(_ code: String) -> Bool {
        guard [8, 12, 13].contains(code.count), code.allSatisfy(\.isASCII), code.allSatisfy(\.isNumber) else {
            return false
        }
        let digits = code.compactMap(\.wholeNumberValue)
        let body = digits.dropLast()
        let sum = body.reversed().enumerated().reduce(0) { total, item in
            total + item.element * (item.offset % 2 == 0 ? 3 : 1)
        }
        return (10 - sum % 10) % 10 == digits.last
    }

    static func parse(_ data: Data, ean: String) throws -> ProductInfo? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw OpenFoodFactsError.invalidResponse
        }
        guard (json["status"] as? Int) == 1, let product = json["product"] as? [String: Any],
              let nutriments = product["nutriments"] as? [String: Any] else { return nil }

        func number(_ key: String) -> Double? {
            let value = nutriments[key]
            if let double = value as? Double { return double.isFinite && double >= 0 ? double : nil }
            if let string = value as? String, let double = Double(string.replacingOccurrences(of: ",", with: ".")) {
                return double.isFinite && double >= 0 ? double : nil
            }
            return nil
        }

        let calories = number("energy-kcal_100g") ?? number("energy-kj_100g").map { $0 / 4.184 }
        guard let calories, let protein = number("proteins_100g"), let carbs = number("carbohydrates_100g"),
              let fat = number("fat_100g") else { return nil }

        let sodiumMg = number("sodium_100g").map { $0 * 1000 } ?? number("salt_100g").map { $0 * 400 } ?? 0
        let names = ["product_name_pt", "product_name", "product_name_en"]
        let name = names.compactMap { (product[$0] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? "Product \(ean)"
        let brand = (product["brands"] as? String)?
            .split(separator: ",").first
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .flatMap { $0.isEmpty ? nil : $0 }

        let unit = (product["product_quantity_unit"] as? String)?.lowercased()
        let package = positive(product["product_quantity"]).flatMap { unit == nil || unit == "g" || unit == "ml" ? $0 : nil }
            ?? (product["quantity"] as? String).flatMap(packageGrams)

        return ProductInfo(
            ean: ean, name: String(name.prefix(120)), brand: brand.map { String($0.prefix(60)) },
            caloriesPer100: calories, proteinPer100: protein, carbsPer100: carbs, fatPer100: fat,
            fiberPer100: number("fiber_100g") ?? 0, sugarPer100: number("sugars_100g") ?? 0,
            saturatedFatPer100: number("saturated-fat_100g") ?? 0, sodiumMgPer100: sodiumMg,
            potassiumMgPer100: (number("potassium_100g") ?? 0) * 1000,
            calciumMgPer100: (number("calcium_100g") ?? 0) * 1000,
            servingG: positive(product["serving_quantity"]), packageG: package
        )
    }

    static func packageGrams(_ quantity: String) -> Double? {
        let pattern = #"^\s*(\d+(?:[.,]\d+)?)\s*(g|gr|kg|ml|cl|l)\.?\s*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: quantity, range: NSRange(quantity.startIndex..., in: quantity)),
              let numberRange = Range(match.range(at: 1), in: quantity),
              let unitRange = Range(match.range(at: 2), in: quantity),
              let number = Double(quantity[numberRange].replacingOccurrences(of: ",", with: ".")) else { return nil }
        let factor: Double = switch quantity[unitRange].lowercased() {
        case "kg", "l": 1000
        case "cl": 10
        default: 1
        }
        return positive(number * factor)
    }

    private static func positive(_ value: Any?) -> Double? {
        let double: Double?
        if let number = value as? Double { double = number }
        else if let string = value as? String { double = Double(string.replacingOccurrences(of: ",", with: ".")) }
        else { double = nil }
        guard let double, double.isFinite, double > 0, double < 10_000 else { return nil }
        return double
    }
}
