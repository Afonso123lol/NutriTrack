import SwiftUI

struct MainTabView: View {
    let profile: UserProfile
    @Environment(\.theme) private var theme
    @State private var selection = AppTab.today
    @State private var isCapturing = false
    @State private var isCaptureHidden = false

    enum AppTab: Hashable {
        case today
        case nutrition
        case training
        case trends
        case profile
    }

    var body: some View {
        TabView(selection: $selection) {
            Tab("Today", systemImage: "sun.max.fill", value: AppTab.today) {
                TodayView(profile: profile) { selection = $0 }
            }
            Tab("Nutrition", systemImage: "fork.knife", value: AppTab.nutrition) {
                NutritionView(profile: profile)
            }
            Tab("Training", systemImage: "figure.hiking", value: AppTab.training) {
                TrainingView(profile: profile)
            }
            Tab("Trends", systemImage: "chart.line.uptrend.xyaxis", value: AppTab.trends) {
                TrendsView(profile: profile)
            }
            Tab("Profile", systemImage: "person.fill", value: AppTab.profile) {
                SettingsView(profile: profile)
            }
        }
        .overlay {
            ZStack(alignment: .bottomTrailing) {
                Color.clear
                    .allowsHitTesting(false)
                if !isCaptureHidden {
                    Button { isCapturing = true } label: {
                        Image(systemName: "plus")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(theme.colors.onAccent)
                            .frame(width: 36, height: 36)
                }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.circle)
                .tint(theme.colors.accent)
                .padding(.trailing, 18)
                .padding(.bottom, 96)
                .accessibilityLabel("Log a meal")
                .transition(.scale.combined(with: .opacity))
                }
            }
            .ignoresSafeArea(.container, edges: .bottom)
            .ignoresSafeArea(.keyboard)
        }
        .onPreferenceChange(CaptureButtonHiddenKey.self) { isHidden in
            withAnimation(.easeOut(duration: 0.2)) { isCaptureHidden = isHidden }
        }
        .sheet(isPresented: $isCapturing) {
            CameraView(profile: profile)
        }
    }
}
