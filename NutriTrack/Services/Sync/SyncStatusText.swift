import Foundation

nonisolated enum SyncStatusText {
    static func describe(isConfigured: Bool, pendingCount: Int, lastSentAt: Date?, lastError: String?,
                         time: (Date) -> String) -> String {
        guard isConfigured else { return "Sync off" }
        if let lastError { return "\(pendingCount) pending · \(lastError)" }
        guard let lastSentAt else { return pendingCount == 0 ? "Nothing sent yet" : "\(pendingCount) pending" }
        let sent = "last sent \(time(lastSentAt))"
        return pendingCount == 0 ? "Up to date · \(sent)" : "\(pendingCount) pending · \(sent)"
    }
}
