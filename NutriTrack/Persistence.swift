import CoreData

struct Persistence {
    static let shared = Persistence()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "NutriTrack")
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores { _, error in
            if let error { fatalError("CoreData failed: \(error)") }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}
