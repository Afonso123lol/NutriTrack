import UIKit
import CoreData

final class SyncEngine {
    static let shared: SyncEngine? = SyncConfig.current().map {
        SyncEngine(config: $0, context: Persistence.shared.container.viewContext, directory: SyncEngine.defaultDirectory)
    }

    nonisolated static var defaultDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Sync", isDirectory: true)
    }

    let queue: SyncQueue
    let client: SyncClient
    let config: SyncConfig
    private let context: NSManagedObjectContext
    private let observer: SyncChangeObserver
    private var loggedLaunches: Set<String> = []

    init(config: SyncConfig, context: NSManagedObjectContext, directory: URL) {
        let queue = SyncQueue(directory: directory)
        let client = SyncClient(config: config, queue: queue, context: context, directory: directory,
                                appState: { SyncEngine.appState() })
        self.queue = queue
        self.client = client
        self.config = config
        self.context = context
        self.observer = SyncChangeObserver(context: context, queue: queue) { client.scheduleSend() }
    }

    static func appState() -> String {
        switch UIApplication.shared.applicationState {
        case .active: return "active"
        case .background: return "background"
        default: return "inactive"
        }
    }

    static var isSimulator: Bool { SyncConfig.isSimulator }

    func saveWithoutQueueing(_ context: NSManagedObjectContext) {
        observer.isSuppressed = true
        try? context.save()
        observer.isSuppressed = false
    }

    nonisolated static func launchEvent(inBackground: Bool, logged: Set<String>) -> String? {
        let kind = inBackground ? "app.backgroundLaunch" : "app.launch"
        if logged.contains(kind) { return nil }
        if inBackground && logged.contains("app.launch") { return nil }
        return kind
    }

    func start() {
        client.activate()
        if SyncBackfill.runIfNeeded(context: context, queue: queue) {
            client.scheduleSend()
        }
    }

    func logLaunch(inBackground: Bool) {
        guard let kind = Self.launchEvent(inBackground: inBackground, logged: loggedLaunches) else { return }
        loggedLaunches.insert(kind)
        log(kind, schedulesSend: !inBackground, [
            "model": UIDevice.current.model,
            "system": UIDevice.current.systemVersion,
            "simulator": String(Self.isSimulator),
            "version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        ])
    }

    func log(_ kind: String, schedulesSend: Bool = true, _ details: [String: String] = [:]) {
        queue.appendEvent(kind: kind, appState: Self.appState(), details: details)
        if schedulesSend && !kind.hasPrefix("sync.") { client.scheduleSend() }
    }
}
