import SwiftUI

struct ScreenHeader<Trailing: View>: View {
    @Environment(\.theme) private var theme
    let eyebrow: String
    let title: String
    let trailing: Trailing

    init(eyebrow: String, title: String, @ViewBuilder trailing: () -> Trailing) {
        self.eyebrow = eyebrow
        self.title = title
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                EyebrowText(eyebrow)
                Text(title)
                    .font(theme.display(.largeTitle))
                    .tracking(theme.typography.titleTracking)
                    .foregroundStyle(theme.colors.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .accessibilityAddTraits(.isHeader)
            }
            Spacer(minLength: 0)
            trailing
        }
        .padding(.top, 8)
    }
}

extension ScreenHeader where Trailing == EmptyView {
    init(eyebrow: String, title: String) {
        self.init(eyebrow: eyebrow, title: title) { EmptyView() }
    }
}
