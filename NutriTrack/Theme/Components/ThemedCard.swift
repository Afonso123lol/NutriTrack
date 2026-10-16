import SwiftUI

struct ThemedCard: ViewModifier {
    @Environment(\.theme) private var theme
    let padding: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: theme.shape.cardRadius, style: .continuous)
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.colors.surface, in: shape)
            .overlay {
                switch theme.shape.cardStyle {
                case .filled:
                    EmptyView()
                case .outlined:
                    shape.strokeBorder(theme.colors.border, lineWidth: 1)
                case .lit:
                    shape.strokeBorder(
                        LinearGradient(colors: [theme.colors.textPrimary.opacity(0.10), theme.colors.textPrimary.opacity(0)],
                                       startPoint: .top, endPoint: .center),
                        lineWidth: 1)
                }
            }
    }
}

extension View {
    func themedCard(padding: CGFloat = 16) -> some View {
        modifier(ThemedCard(padding: padding))
    }
}
