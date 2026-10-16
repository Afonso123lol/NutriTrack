import XCTest
import UIKit
@testable import NutriTrack

@MainActor
final class PendingMealStoreTests: XCTestCase {

    private func tempDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("pending-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func seedFailedItem(id: UUID, in dir: URL) throws {
        let snapshot: [String: Any] = ["id": id.uuidString, "createdAt": 0, "state": "failed", "errorMessage": "x"]
        try JSONSerialization.data(withJSONObject: snapshot).write(to: dir.appendingPathComponent("\(id.uuidString).json"))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8), format: format).image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        }
        try XCTUnwrap(image.jpegData(compressionQuality: 0.8)).write(to: dir.appendingPathComponent("\(id.uuidString).jpg"))
    }

    private func sampleAnalysis() throws -> NutritionAnalysis {
        let json = #"{"dishName":"Grilled chicken with rice","calories":520,"proteinG":42,"carbsG":55,"fatG":12,"saturatedFatG":3.5,"omega3G":0.4,"fiberG":2.1,"sugarG":1.5,"sodiumMg":680,"potassiumMg":900,"calciumMg":45,"ironMg":3.5,"zincMg":4.2,"magnesiumMg":85,"phosphorusMg":320,"seleniumUg":28,"copperUg":120,"vitaminCMg":15,"vitaminDUg":0.8,"vitaminEMg":1.2,"vitaminKUg":35,"vitaminB1Mg":0.4,"vitaminB2Mg":0.3,"vitaminB3Mg":12,"vitaminB5Mg":1.8,"vitaminB6Mg":0.9,"vitaminB12Ug":1.8,"folateUg":42}"#
        return try JSONDecoder().decode(NutritionAnalysis.self, from: Data(json.utf8))
    }

    func testAppliedResultPersistsAcrossReload() throws {
        let dir = tempDirectory()
        let id = UUID()
        try seedFailedItem(id: id, in: dir)

        let store = PendingMealStore(directory: dir)
        XCTAssertEqual(store.items.count, 1)
        store.applyAnalysisStatus(itemID: id, status: .done(try sampleAnalysis()))

        let reloaded = PendingMealStore(directory: dir)
        guard case .done(let analysis) = reloaded.items.first?.status else {
            return XCTFail("expected done after reload")
        }
        XCTAssertEqual(analysis.dishName, "Grilled chicken with rice")
    }

    func testTextOnlyItemReloadsWithoutAPhoto() throws {
        let dir = tempDirectory()
        let id = UUID()
        let snapshot: [String: Any] = ["id": id.uuidString, "createdAt": 0, "eatenAt": -3600, "state": "failed",
                                       "errorMessage": "x", "hasImage": false, "note": "2 chorizo rolls"]
        try JSONSerialization.data(withJSONObject: snapshot).write(to: dir.appendingPathComponent("\(id.uuidString).json"))
        let store = PendingMealStore(directory: dir)
        XCTAssertEqual(store.items.count, 1)
        XCTAssertNil(store.items.first?.image)
        XCTAssertEqual(store.items.first?.note, "2 chorizo rolls")
        XCTAssertEqual(store.items.first?.eatenAt, Date(timeIntervalSinceReferenceDate: -3600))
    }

    func testOlderSnapshotStillLoadsWithItsPhotoAndTime() throws {
        let dir = tempDirectory()
        let id = UUID()
        try seedFailedItem(id: id, in: dir)
        let store = PendingMealStore(directory: dir)
        XCTAssertNotNil(store.items.first?.image)
        XCTAssertEqual(store.items.first?.eatenAt, Date(timeIntervalSinceReferenceDate: 0))
    }

    func testSnapshotThatLostItsPhotoIsDropped() throws {
        let dir = tempDirectory()
        let id = UUID()
        let snapshot: [String: Any] = ["id": id.uuidString, "createdAt": 0, "state": "failed", "errorMessage": "x"]
        try JSONSerialization.data(withJSONObject: snapshot).write(to: dir.appendingPathComponent("\(id.uuidString).json"))
        XCTAssertTrue(PendingMealStore(directory: dir).items.isEmpty)
    }

    func testResultForUnknownItemIsIgnored() throws {
        let dir = tempDirectory()
        let id = UUID()
        try seedFailedItem(id: id, in: dir)
        let store = PendingMealStore(directory: dir)
        store.applyAnalysisStatus(itemID: UUID(), status: .failed("other"))
        guard case .failed(let message) = store.items.first?.status else { return XCTFail("expected failed") }
        XCTAssertEqual(message, "x")
    }
}
