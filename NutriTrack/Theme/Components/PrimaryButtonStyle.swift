import SwiftUI

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.theme) private var theme
    @Environment(\.isEnabled) private var isEnabled
    var fill: Color? = nil

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(theme.body(.body).weight(.semibold))
            .foregroundStyle(isEnabled ? theme.colors.onAccent : theme.colors.textMuted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                isEnabled ? (fill ?? theme.colors.accent) : theme.colors.textMuted.opacity(0.3),
                in: RoundedRectangle(cornerRadius: theme.shape.controlRadius, style: .continuous)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var themedPrimary: PrimaryButtonStyle { PrimaryButtonStyle() }

    static func themedPrimary(fill: Color) -> PrimaryButtonStyle { PrimaryButtonStyle(fill: fill) }
}

struct CompactButtonStyle: ButtonStyle {
    @Environment(\.theme) private var theme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(theme.body(.subheadline).weight(.semibold))
            .foregroundStyle(theme.colors.onAccent)
            .padding(.horizontal, 18)
            .frame(minHeight: 44)
            .background(theme.colors.accent,
                        in: RoundedRectangle(cornerRadius: theme.shape.controlRadius, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == CompactButtonStyle {
    static var themedCompact: CompactButtonStyle { CompactButtonStyle() }
}

struct OutlineButtonStyle: ButtonStyle {
    @Environment(\.theme) private var theme

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: theme.shape.controlRadius, style: .continuous)
        configuration.label
            .font(theme.body(.body).weight(.semibold))
            .foregroundStyle(theme.colors.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .overlay(shape.strokeBorder(theme.colors.textMuted, lineWidth: 1))
            .contentShape(shape)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == OutlineButtonStyle {
    static var themedOutline: OutlineButtonStyle { OutlineButtonStyle() }
}
