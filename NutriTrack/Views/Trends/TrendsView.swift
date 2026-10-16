import SwiftUI

struct TrendsView: View {
    @Environment(\.theme) private var theme
    @ObservedObject var profile: UserProfile

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                ScreenHeader(eyebrow: "Progress", title: "Trends")
                WeightLogView(profile: profile)
            }
            .padding(.horizontal, 16)
            .background(theme.colors.background.ignoresSafeArea())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(theme.colors.background, for: .navigationBar)
            .toolbarBackgroundVisibility(.visible, for: .navigationBar)
        }
    }
}
