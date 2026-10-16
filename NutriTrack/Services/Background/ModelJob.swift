import Foundation
import UIKit

nonisolated enum ModelJobKind: Codable, Hashable, Sendable {
    case mealAnalysis(pendingItemID: UUID)
    case dailyCoach(day: Date)
    case scoreEvaluation(day: Date)
    case dietEvaluation(day: Date)
}

nonisolated struct ModelJob: Codable, Hashable, Sendable, Identifiable {
    let id: UUID
    let kind: ModelJobKind
    var attempt: Int
    let createdAt: Date

    init(kind: ModelJobKind, id: UUID = UUID(), attempt: Int = 0, createdAt: Date = Date()) {
        self.id = id
        self.kind = kind
        self.attempt = attempt
        self.createdAt = createdAt
    }
}

nonisolated enum ModelRetryPolicy {
    static let maxRetries = 20

    static func shouldRetry(statusCode: Int?, errorCode: URLError.Code?, attempt: Int) -> Bool {
        guard attempt < maxRetries else { return false }
        if let errorCode {
            return errorCode == .timedOut || errorCode == .networkConnectionLost || errorCode == .cannotConnectToHost
        }
        guard let statusCode else { return false }
        return statusCode == 429 || (500...599).contains(statusCode)
    }

    static func shouldRetryUnreadableAnswer(attempt: Int) -> Bool {
        attempt < maxRetries
    }

    static func delay(beforeAttempt attempt: Int) -> TimeInterval {
        let delays: [TimeInterval] = [0, 5, 15, 60, 300]
        return attempt < delays.count ? delays[max(0, attempt)] : 900
    }
}

nonisolated enum ModelNotification {
    static func shouldNotify(applicationState: UIApplication.State) -> Bool {
        applicationState != .active
    }

    static func content(for kind: ModelJobKind, succeeded: Bool) -> (title: String, body: String) {
        switch (kind, succeeded) {
        case (.mealAnalysis, true): return ("Meal analysed", "Tap to review and save it.")
        case (.mealAnalysis, false): return ("Meal analysis failed", "Open the app to retry.")
        case (.dailyCoach, true): return ("Your day analysis is ready", "Tap to read your coach's recommendations.")
        case (.dailyCoach, false): return ("Day analysis failed", "Open the app to try again.")
        case (.scoreEvaluation, true): return ("Today's scores are ready", "Tap to see what drove them.")
        case (.scoreEvaluation, false): return ("Score analysis failed", "Open the app to try again.")
        case (.dietEvaluation, true): return ("Your diet review is ready", "Tap to see what drove the score.")
        case (.dietEvaluation, false): return ("Diet review failed", "Open the app to try again.")
        }
    }
}

nonisolated extension ModelJob {
    var eventDetails: [String: String] {
        let kindName: String
        switch kind {
        case .mealAnalysis: kindName = "mealAnalysis"
        case .dailyCoach: kindName = "dailyCoach"
        case .scoreEvaluation: kindName = "scoreEvaluation"
        case .dietEvaluation: kindName = "dietEvaluation"
        }
        return ["jobID": id.uuidString, "kind": kindName, "attempt": String(attempt),
                "model": GeminiService.modelID(forAttempt: attempt)]
    }
}
