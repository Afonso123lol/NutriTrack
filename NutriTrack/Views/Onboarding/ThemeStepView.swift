import SwiftUI

struct ThemeStepView: View {
    @Environment(\.theme) private var theme
    let name: String
    let onComplete: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ScreenHeader(eyebrow: "Step 3 of 3", title: "Choose your look")
                    Text("You can change this anytime in Profile.")
                        .font(theme.body(.subheadline))
                        .foregroundStyle(theme.colors.textSecondary)
                    ThemePickerView(name: name.isEmpty ? nil : name)
                }
                .padding(16)
                .padding(.bottom, 24)
            }
            .background(theme.colors.background.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                Button("Finish", action: onComplete)
                    .buttonStyle(.themedPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(theme.colors.background)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(theme.colors.background, for: .navigationBar)
            .toolbarBackgroundVisibility(.visible, for: .navigationBar)
        }
    }
}
