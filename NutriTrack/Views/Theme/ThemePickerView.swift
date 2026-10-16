import SwiftUI

struct ThemePickerView: View {
    @Environment(\.theme) private var theme
    @AppStorage("themeID") private var themeID = Theme.alpine.id
    let name: String?

    private let columns = [
        GridItem(.flexible(), spacing: 14, alignment: .top),
        GridItem(.flexible(), spacing: 14, alignment: .top)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 18) {
            ForEach(Theme.all) { preset in
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    themeID = preset.id
                } label: {
                    tile(for: preset)
                }
                .buttonStyle(.pressScale)
                .accessibilityLabel("\(preset.name) theme")
                .accessibilityAddTraits(preset.id == themeID ? .isSelected : [])
            }
        }
    }

    private func tile(for preset: Theme) -> some View {
        let isSelected = preset.id == themeID
        let frame = RoundedRectangle(cornerRadius: preset.shape.cardRadius, style: .continuous)
        return VStack(alignment: .leading, spacing: 8) {
            ThemePreviewTile(name: name)
                .environment(\.theme, preset)
                .aspectRatio(3 / 4, contentMode: .fit)
                .clipShape(frame)
                .overlay {
                    frame.strokeBorder(isSelected ? theme.colors.accent : preset.colors.textMuted.opacity(0.45),
                                       lineWidth: isSelected ? 2 : 0.5)
                }
                .overlay(alignment: .topTrailing) {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(theme.colors.onAccent, theme.colors.accent)
                            .font(.system(size: 20))
                            .padding(8)
                    }
                }
            Text(preset.name)
                .font(theme.display(.headline))
                .foregroundStyle(theme.colors.textPrimary)
            Text(preset.tagline)
                .font(theme.body(.caption))
                .foregroundStyle(theme.colors.textSecondary)
        }
        .contentShape(Rectangle())
    }
}

struct ThemePickerScreen: View {
    @Environment(\.theme) private var theme
    let name: String?

    var body: some View {
        ScrollView {
            ThemePickerView(name: name)
                .padding(16)
        }
        .background(theme.colors.background.ignoresSafeArea())
        .navigationTitle("Theme")
        .navigationBarTitleDisplayMode(.inline)
    }
}
