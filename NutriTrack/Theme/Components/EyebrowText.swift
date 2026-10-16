import SwiftUI

struct EyebrowText: View {
    @Environment(\.theme) private var theme
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(theme.body(.caption).weight(.semibold))
            .tracking(theme.typography.eyebrowTracking)
            .foregroundStyle(theme.colors.textSecondary)
            .textCase(theme.typography.isEyebrowUppercase ? .uppercase : nil)
    }
}
