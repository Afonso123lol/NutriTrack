import Foundation

nonisolated enum MultilineField {
    static func handleReturn(in text: String) -> (text: String, shouldClose: Bool) {
        guard text.contains("\n") else { return (text, false) }
        let joined = text
            .split(separator: "\n", omittingEmptySubsequences: true)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
        return (joined, true)
    }
}
