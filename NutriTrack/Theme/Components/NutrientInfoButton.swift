import SwiftUI

struct NutrientInfoButton: View {
    let label: String
    var basis: String? = nil

    @Environment(\.theme) private var theme
    @State private var isPresented = false
    @State private var isInLowerHalf = false

    var body: some View {
        if let info = NutrientInfo.forLabel(label) {
            Button {
                isPresented = true
            } label: {
                Image(systemName: "questionmark.circle")
                    .font(.caption)
                    .foregroundStyle(theme.colors.textMuted)
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Why \(info.name) is tracked")
            .onGeometryChange(for: Bool.self) { proxy in
                guard let visible = proxy.bounds(of: .scrollView) else { return false }
                return proxy.size.height / 2 > visible.midY
            } action: { isLower in
                isInLowerHalf = isLower
            }
            .popover(isPresented: $isPresented, arrowEdge: isInLowerHalf ? .bottom : .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(info.name)
                        .font(theme.display(.headline))
                        .foregroundStyle(theme.colors.textPrimary)
                    Text(info.why)
                        .font(theme.body(.subheadline))
                        .foregroundStyle(theme.colors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Found in: \(info.sources)")
                        .font(theme.body(.caption))
                        .foregroundStyle(theme.colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let basis {
                        Text(basis)
                            .font(theme.body(.caption))
                            .foregroundStyle(theme.colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(16)
                .frame(width: 290, alignment: .leading)
                .presentationCompactAdaptation(.popover)
            }
        }
    }
}
