import SwiftUI

struct ThemePreviewTile: View {
    @Environment(\.theme) private var theme
    let name: String?

    private static let sample = WeekPath.make(plannedByDay: [25, 0, 25, 0, 30, 0, 45],
                                              doneByDay: [25, 0, 25, 0, 0, 0, 0], todayIndex: 3)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            EyebrowText("Good to go")
            Text("Ready to move.")
                .font(theme.display(.headline))
                .tracking(theme.typography.titleTracking)
                .foregroundStyle(theme.colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            hero
            Spacer(minLength: 0)
            HStack(spacing: 6) {
                StatCard(label: "Sleep", value: "7.5 h")
                StatCard(label: "Protein", value: "92 g")
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(alignment: .top) {
            ScreenBackdrop(tone: theme.colors.dayGo)
        }
        .background(theme.colors.background)
        .dynamicTypeSize(.large)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var hero: some View {
        switch theme.style.hero {
        case .arc:
            ZStack {
                Circle()
                    .trim(from: 0, to: 0.75)
                    .stroke(theme.colors.border, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(135))
                Circle()
                    .trim(from: 0, to: 0.75 * 0.78)
                    .stroke(theme.colors.dayGo, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(135))
                Text("78")
                    .font(theme.hero(26))
                    .foregroundStyle(theme.colors.textPrimary)
            }
            .frame(width: 70, height: 70)
        case .numeral:
            VStack(alignment: .leading, spacing: 4) {
                Text("78")
                    .font(theme.hero(44))
                    .foregroundStyle(theme.colors.textPrimary)
                TargetBar(geometry: TargetBarGeometry(fill: 0.78, tick: nil, zone: nil, isOver: false),
                          color: theme.colors.accent, isProminent: true)
            }
        case .path:
            WeekPathChart(path: Self.sample, color: theme.colors.readiness, height: 64)
        }
    }
}
