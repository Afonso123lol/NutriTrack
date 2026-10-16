import Foundation

final class ModelJobRouter {
    private let store: ModelJobStore
    private let resend: (ModelJob) -> Void
    private let applyMeal: (UUID, PendingMealStatus) -> Void
    private let applyCoach: (Date, String) -> Void
    private let applyScores: (Date, ScoreEvaluationTexts) -> Void
    private let applyDiet: (Date, String) -> Void
    private let notify: (ModelJobKind, Bool) -> Void
    private let logEvent: (String, [String: String]) -> Void

    init(store: ModelJobStore,
         resend: @escaping (ModelJob) -> Void,
         applyMeal: @escaping (UUID, PendingMealStatus) -> Void,
         applyCoach: @escaping (Date, String) -> Void,
         applyScores: @escaping (Date, ScoreEvaluationTexts) -> Void,
         applyDiet: @escaping (Date, String) -> Void,
         notify: @escaping (ModelJobKind, Bool) -> Void,
         logEvent: @escaping (String, [String: String]) -> Void) {
        self.store = store
        self.resend = resend
        self.applyMeal = applyMeal
        self.applyCoach = applyCoach
        self.applyScores = applyScores
        self.applyDiet = applyDiet
        self.notify = notify
        self.logEvent = logEvent
    }

    func handle(jobID: UUID, data: Data, statusCode: Int?, error: Error?) {
        guard let job = store.job(id: jobID) else { return }
        let errorCode = (error as? URLError)?.code
        if errorCode == .cancelled { return }

        guard error == nil, statusCode == 200 else {
            if ModelRetryPolicy.shouldRetry(statusCode: statusCode, errorCode: errorCode, attempt: job.attempt) {
                retry(job, reason: failureMessage(statusCode: statusCode, error: error))
            } else {
                fail(job, message: failureMessage(statusCode: statusCode, error: error))
            }
            return
        }

        do {
            switch job.kind {
            case .mealAnalysis(let itemID):
                applyMeal(itemID, .done(try GeminiService.parseNutritionResponse(data)))
            case .dailyCoach(let day):
                applyCoach(day, try GeminiService.parseCoachResponse(data))
            case .scoreEvaluation(let day):
                applyScores(day, try GeminiService.parseScoreEvaluationResponse(data))
            case .dietEvaluation(let day):
                applyDiet(day, try GeminiService.parseDietEvaluationResponse(data))
            }
            store.remove(id: job.id)
            logEvent("model.completed", job.eventDetails.merging(
                ["durationS": String(format: "%.1f", Date().timeIntervalSince(job.createdAt))]) { $1 })
            notify(job.kind, true)
        } catch {
            if case GeminiError.parsingError = error, ModelRetryPolicy.shouldRetryUnreadableAnswer(attempt: job.attempt) {
                retry(job, reason: error.localizedDescription)
            } else {
                fail(job, message: error.localizedDescription)
            }
        }
    }

    private func retry(_ job: ModelJob, reason: String) {
        var next = job
        next.attempt += 1
        store.update(next)
        logEvent("model.retry", next.eventDetails.merging(["reason": reason]) { $1 })
        resend(next)
    }

    private func fail(_ job: ModelJob, message: String) {
        if case .mealAnalysis(let itemID) = job.kind {
            applyMeal(itemID, .failed(message))
        }
        store.remove(id: job.id)
        store.recordFailure(message, for: job.kind)
        logEvent("model.failed", job.eventDetails.merging(["error": message]) { $1 })
        notify(job.kind, false)
    }

    private func failureMessage(statusCode: Int?, error: Error?) -> String {
        if let error {
            return ((error as? GeminiError) ?? .networkError(error.localizedDescription)).localizedDescription
        }
        if statusCode == 429 { return GeminiError.rateLimitExceeded.localizedDescription }
        return GeminiError.networkError("HTTP \(statusCode ?? 0)").localizedDescription
    }
}
