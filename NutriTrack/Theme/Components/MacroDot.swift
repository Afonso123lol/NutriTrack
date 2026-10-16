import SwiftUI

struct MacroDot: View {
    @Environment(\.theme) private var theme
    let letter: String
    let color: Color
    var size: CGFloat = 22

    var body: some View {
        Text(letter)
            .font(theme.meta(.caption2).weight(.bold))
            .foregroundStyle(theme.colors.background)
            .frame(width: size, height: size)
            .background(color, in: Circle())
            .accessibilityHidden(true)
    }
}
