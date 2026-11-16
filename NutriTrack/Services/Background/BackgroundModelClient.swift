import Foundation
import CoreData

final class BackgroundModelClient: NSObject {
    static let identifier = "magalhaes.NutriTrack.model"
    static let shared = BackgroundModelClient()

    var backgroundCompletionHandler: (() -> Void)?

    private var buffers: [Int: Data] = [:]
    private var inFlightTasks: [UUID: Int] = [:]

    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.background(withIdentifier: Self.identifier)
        configuration.isDiscretionary = false
        configuration.sessionSendsLaunchEvents = true
        configuration.timeoutIntervalForRequest = 300
        configuration.timeoutIntervalForResource = 60 * 60
        return URLSession(configuration: configuration, delegate: self, delegateQueue: .main)
    }()

    func activate() {
        _ = session
    }

    func enqueue(_ kind: ModelJobKind, body: Data) throws {
        let job = ModelJob(kind: kind)
        try ModelJobStore.shared.add(job, body: body)
        SyncEngine.shared?.log("model.enqueued", job.eventDetails)
        ModelNotifier.requestAuthorizationIfNeeded()
        send(job)
    }

    func send(_ job: ModelJob) {
        guard inFlightTasks[job.id] == nil else { return }
        guard let apiKey = GeminiService.configuredAPIKey(),
              let request = GeminiService.endpointRequest(apiKey: apiKey,
                                                          modelID: GeminiService.modelID(forAttempt: job.attempt)) else {
            Task {
                ModelJobRouter.shared.handle(jobID: job.id, data: Data(), statusCode: nil,
                                             error: GeminiError.networkError("GEMINI_API_KEY not configured"))
            }
            return
        }
        let task = session.uploadTask(with: request, fromFile: ModelJobStore.shared.bodyURL(for: job.id))
        task.taskDescription = job.id.uuidString
        if job.attempt > 0 {
            task.earliestBeginDate = Date().addingTimeInterval(ModelRetryPolicy.delay(beforeAttempt: job.attempt))
        }
        inFlightTasks[job.id] = task.taskIdentifier
        task.resume()
        SyncEngine.shared?.log("model.sent", job.eventDetails)
    }

    func cancel(jobID: UUID) {
        let description = jobID.uuidString
        session.getAllTasks { tasks in
            tasks.filter { $0.taskDescription == description }.forEach { $0.cancel() }
        }
    }

    func resumeOrphanedJobs() {
        session.getAllTasks { tasks in
            let active = Set(tasks.filter { $0.state == .running || $0.state == .suspended }.compactMap(\.taskDescription))
            Task { @MainActor in
                for job in ModelJobStore.shared.jobs where !active.contains(job.id.uuidString) {
                    BackgroundModelClient.shared.send(job)
                }
            }
        }
    }
}

extension BackgroundModelClient: URLSessionDataDelegate {
    nonisolated func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        MainActor.assumeIsolated {
            buffers[dataTask.taskIdentifier, default: Data()].append(data)
        }
    }

    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        MainActor.assumeIsolated {
            let data = buffers.removeValue(forKey: task.taskIdentifier) ?? Data()
            guard let description = task.taskDescription, let jobID = UUID(uuidString: description) else { return }
            if inFlightTasks[jobID] == task.taskIdentifier { inFlightTasks[jobID] = nil }
            let statusCode = (task.response as? HTTPURLResponse)?.statusCode
            ModelJobRouter.shared.handle(jobID: jobID, data: data, statusCode: statusCode, error: error)
        }
    }

    nonisolated func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        MainActor.assumeIsolated {
            backgroundCompletionHandler?()
            backgroundCompletionHandler = nil
        }
    }
}

extension ModelJobRouter {
    static let shared = ModelJobRouter(
        store: .shared,
        resend: { BackgroundModelClient.shared.send($0) },
        applyMeal: { PendingMealStore.shared.applyAnalysisStatus(itemID: $0, status: $1) },
        applyCoach: { EvaluationService.saveCoachText($1, day: $0, in: Persistence.shared.container.viewContext) },
        notify: { ModelNotifier.post(kind: $0, succeeded: $1) },
        logEvent: { SyncEngine.shared?.log($0, $1) }
    )
}
