import Foundation

enum ProductLookup: Equatable {
    case found(ProductInfo)
    case notFound
    case failed(String)
}

enum OpenFoodFactsClient {
    static func lookup(ean: String, session: URLSession = .shared) async -> ProductLookup {
        guard let url = OpenFoodFacts.productURL(ean: ean) else { return .failed("This barcode is not valid.") }
        var request = URLRequest(url: url, timeoutInterval: 12)
        request.setValue(OpenFoodFacts.userAgent, forHTTPHeaderField: "User-Agent")
        do {
            let (data, response) = try await session.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if status == 404 { return .notFound }
            guard status == 200 else { return .failed("Open Food Facts is busy (HTTP \(status)). Try again in a minute.") }
            return try OpenFoodFacts.parse(data, ean: ean).map(ProductLookup.found) ?? .notFound
        } catch is OpenFoodFactsError {
            return .failed("Open Food Facts sent an answer the app could not read.")
        } catch {
            return .failed("No connection to Open Food Facts. Check the network and try again.")
        }
    }
}
