import XCTest
import CoreData
@testable import NutriTrack

@MainActor
final class SyncChangeObserverTests: XCTestCase {

    @MainActor
    private final class Counter {
        var value = 0
    }

    private var ctx: NSManagedObjectContext!
    private var queue: SyncQueue!
    private var observer: SyncChangeObserver!
    private var changes: Counter!

    override func setUp() {
        super.setUp()
        ctx = Persistence(inMemory: true).container.viewContext
        queue = SyncQueue(directory: FileManager.default.temporaryDirectory
            .appendingPathComponent("observer-\(UUID().uuidString)", isDirectory: true))
        let counter = Counter()
        changes = counter
        observer = SyncChangeObserver(context: ctx, queue: queue) { counter.value += 1 }
    }

    override func tearDown() {
        observer = nil
        queue = nil
        ctx = nil
        changes = nil
        super.tearDown()
    }

    private func makeWeight() -> (WeightEntry, SyncKey) {
        let weight = WeightEntry(context: ctx)
        let id = UUID()
        weight.id = id
        weight.weightKg = 80
        return (weight, SyncKey(entity: "WeightEntry", id: id))
    }

    func testInsertQueuesTheRecord() throws {
        let (_, key) = makeWeight()
        try ctx.save()
        XCTAssertEqual(queue.state.records[key]?.deleted, false)
        XCTAssertTrue(queue.state.photos.isEmpty)
        XCTAssertEqual(changes.value, 1)
    }

    func testInsertWithPhotoQueuesThePhotoToo() throws {
        let entry = FoodEntry(context: ctx)
        let id = UUID()
        entry.id = id
        entry.photoData = Data([0xFF, 0xD8, 0xFF])
        try ctx.save()
        XCTAssertNotNil(queue.state.records[SyncKey(entity: "FoodEntry", id: id)])
        XCTAssertEqual(queue.state.photos, [id])
    }

    func testUpdateQueuesTheRecordAgain() throws {
        let (weight, key) = makeWeight()
        try ctx.save()
        let manifest = queue.beginBatch(keys: [key], lastEventSeq: nil)
        queue.completeBatch(id: manifest.id)
        XCTAssertTrue(queue.state.records.isEmpty)
        weight.weightKg = 81
        try ctx.save()
        XCTAssertEqual(queue.state.records[key]?.deleted, false)
    }

    func testDeleteQueuesATombstone() throws {
        let (weight, key) = makeWeight()
        try ctx.save()
        ctx.delete(weight)
        try ctx.save()
        XCTAssertEqual(queue.state.records[key]?.deleted, true)
    }

    func testObjectWithoutIDIsIgnored() throws {
        let weight = WeightEntry(context: ctx)
        weight.weightKg = 80
        try ctx.save()
        XCTAssertTrue(queue.state.records.isEmpty)
        XCTAssertEqual(changes.value, 0)
    }

    func testInsertedAndDeletedBeforeSavingLeavesNothing() throws {
        let (weight, _) = makeWeight()
        ctx.delete(weight)
        try ctx.save()
        XCTAssertTrue(queue.state.records.isEmpty)
    }

    func testSuppressedSavesAreNotQueued() throws {
        observer.isSuppressed = true
        let meal = FoodEntry(context: ctx)
        meal.id = UUID()
        try ctx.save()
        XCTAssertTrue(queue.state.records.isEmpty)
        XCTAssertEqual(changes.value, 0)

        observer.isSuppressed = false
        meal.calories = 300
        try ctx.save()
        XCTAssertEqual(queue.state.records.count, 1)
        XCTAssertEqual(changes.value, 1)
    }
}
