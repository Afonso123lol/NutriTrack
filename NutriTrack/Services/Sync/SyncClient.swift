import Foundation
import CoreData

final class SyncClient: NSObject {
    static let identifier = "magalhaes.NutriTrack.sync"
    static let maxConcurrentPhotos = 4

    var backgroundCompletionHandler: (() -> Void)?

    private let config: SyncConfig
    private let queue: SyncQueue
    private let context: NSManagedObjectContext
    private let directory: URL
    private let appState: () -> String
    private var buffers: [Int: Data] = [:]
    private var inFlight: [String: Int] = [:]
    private var failedPhotos: Set<UUID> = []
    private var debounce: Task<Void, Never>?

    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.background(withIdentifier: Self.identifier)
        configuration.isDiscretionary = false
        configuration.sessionSendsLaunchEvents = true
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 5 * 60
        return URLSession(configuration: configuration, delegate: self, delegateQueue: .main)
    }()

    init(config: SyncConfig, queue: SyncQueue, context: NSManagedObjectContext, directory: URL,
         appState: @escaping () -> String) {
        self.config = config
        self.queue = queue
        self.context = context
        self.directory = directory
        self.appState = appState
        super.init()
    }

    func activate() {
        _ = session
    }

    func scheduleSend() {
        if appState() == "background" {
            sendNow()
            return
        }
        debounce?.cancel()
        debounce = Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            self?.sendNow()
        }
    }

    func sendNow() {
        session.getAllTasks { tasks in
            let active = Set(tasks.filter { $0.state == .running || $0.state == .suspended }.compactMap(\.taskDescription))
            Task { @MainActor in
                self.send(active: active)
            }
        }
    }

    private func send(active: Set<String>) {
        let live = active.union(inFlight.keys)
        if let manifest = queue.state.inFlightBatch, !live.contains("batch:\(manifest.id.uuidString)") {
            try? FileManager.default.removeItem(at: directory.appendingPathComponent("batch-\(manifest.id.uuidString).json"))
            queue.failBatch(id: manifest.id, error: nil)
        }
        if queue.state.inFlightBatch == nil, SyncBatchBuilder.shouldSend(queue.state),
           let batch = SyncBatchBuilder.build(state: queue.state, context: context) {
            let manifest = queue.beginBatch(keys: batch.keys, lastEventSeq: batch.lastEventSeq)
            let started = upload(batch.body, fileName: "batch-\(manifest.id.uuidString).json",
                                 request: config.request(path: "v1/batch", method: "POST", contentType: "application/json"),
                                 description: "batch:\(manifest.id.uuidString)")
            if !started { queue.failBatch(id: manifest.id, error: "Could not write the batch file") }
        }
        let livePhotos = Set(live.compactMap { $0.hasPrefix("photo:") ? UUID(uuidString: String($0.dropFirst(6))) : nil })
        for id in SyncBatchBuilder.nextPhotos(pending: queue.state.photos, inFlight: livePhotos, skipped: failedPhotos,
                                              limit: Self.maxConcurrentPhotos) {
            guard let object = SyncBatchBuilder.fetch(SyncKey(entity: SyncEntities.photoEntity, id: id), in: context),
                  let data = object.value(forKey: "photoData") as? Data else {
                queue.completePhoto(id, sent: false)
                continue
            }
            _ = upload(data, fileName: "photo-\(id.uuidString).jpg",
                       request: config.request(path: "v1/photos/\(id.uuidString)", method: "PUT", contentType: "image/jpeg"),
                       description: "photo:\(id.uuidString)")
        }
    }

    private func upload(_ body: Data, fileName: String, request: URLRequest, description: String) -> Bool {
        let file = directory.appendingPathComponent(fileName)
        guard (try? body.write(to: file, options: .atomic)) != nil else { return false }
        let task = session.uploadTask(with: request, fromFile: file)
        task.taskDescription = description
        inFlight[description] = task.taskIdentifier
        task.resume()
        return true
    }

    private func finish(description: String, data: Data, statusCode: Int?, error: Error?) {
        let parts = description.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2, let id = UUID(uuidString: parts[1]) else { return }
        if parts[0] == "batch" {
            try? FileManager.default.removeItem(at: directory.appendingPathComponent("batch-\(id.uuidString).json"))
            SyncResponder.handleBatch(id: id, data: data, statusCode: statusCode, error: error, queue: queue, appState: appState())
        } else {
            try? FileManager.default.removeItem(at: directory.appendingPathComponent("photo-\(id.uuidString).jpg"))
            SyncResponder.handlePhoto(id: id, statusCode: statusCode, error: error, queue: queue, appState: appState())
            if queue.state.photos.contains(id) { failedPhotos.insert(id) }
        }
        let succeeded = error == nil && statusCode.map { (200..<300).contains($0) } == true
        if succeeded && queue.pendingCount > 0 { sendNow() }
    }
}

extension SyncClient: URLSessionDataDelegate {
    nonisolated func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        MainActor.assumeIsolated {
            buffers[dataTask.taskIdentifier, default: Data()].append(data)
        }
    }

    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        MainActor.assumeIsolated {
            let data = buffers.removeValue(forKey: task.taskIdentifier) ?? Data()
            guard let description = task.taskDescription else { return }
            if inFlight[description] == task.taskIdentifier { inFlight[description] = nil }
            let statusCode = (task.response as? HTTPURLResponse)?.statusCode
            finish(description: description, data: data, statusCode: statusCode, error: error)
        }
    }

    nonisolated func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        MainActor.assumeIsolated {
            backgroundCompletionHandler?()
            backgroundCompletionHandler = nil
        }
    }
}
