import SwiftUI

extension DayColor {
    func tint(in theme: Theme) -> Color {
        switch self {
        case .green: return theme.colors.dayGo
        case .yellow: return theme.colors.dayEasy
        case .red: return theme.colors.dayRest
        case .unknown: return theme.colors.textSecondary
        }
    }
}
