nonisolated enum Sex: String, CaseIterable, Identifiable, Sendable {
    case male
    case female

    var id: String { rawValue }
    var displayName: String { self == .male ? "Male" : "Female" }
}
