import SwiftUI
import Charts
import CoreData

struct ScaleDetailView: View {
    nonisolated enum Scale: Int, Hashable, Sendable {
        case energy, soreness, stress

        var title: String {
            switch self {
            case .energy: return "Energy"
            case .soreness: return "Muscle soreness"
            case .stress: return "Stress"
            }
        }
    }

    @Environment(\.theme) private var theme
    @Environment(\.managedObjectContext) private var ctx
    let scale: Scale

    private struct Point: Identifiable {
        let date: Date
        let value: Int
        let isSick: Bool
        var id: Date { date }
    }

    var body: some View {
        let start = Calendar.current.startOfDay(for: Date())
        let points = TrainingService.checkIns(from: TrainingService.shifted(start, days: -DayStateBoard.windowDays),
                                              to: TrainingService.shifted(start, days: 1), in: ctx)
            .compactMap { checkIn -> Point? in
                guard let date = checkIn.date else { return nil }
                let value: Int16
                switch scale {
                case .energy: value = checkIn.energyLevel
                case .soreness: value = checkIn.soreness
                case .stress: value = checkIn.stress
                }
                return (1...5).contains(value) ? Point(date: date, value: Int(value), isSick: checkIn.isSick) : nil
            }
        let usual = points.filter { !$0.isSick && $0.date < start }.map(\.value)
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    EyebrowText("Last \(DayStateBoard.windowDays) days")
                    if points.isEmpty {
                        Text("No answers yet.")
                            .font(theme.body(.subheadline))
                            .foregroundStyle(theme.colors.textSecondary)
                    } else {
                        Chart(points) { point in
                            BarMark(x: .value("Day", point.date, unit: .day), y: .value(scale.title, point.value))
                                .foregroundStyle(point.isSick ? theme.colors.textMuted : theme.colors.readiness)
                        }
                        .chartYScale(domain: 0...5)
                        .chartYAxis { AxisMarks(values: [1, 2, 3, 4, 5]) }
                        .frame(height: 180)
                        .accessibilityLabel("\(scale.title) over the last \(DayStateBoard.windowDays) days")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .themedCard()

                VStack(alignment: .leading, spacing: 8) {
                    EyebrowText("Your usual")
                    if usual.count >= DayStateBoard.minimumDays {
                        Text(String(format: "%.1f of 5, from %d days", Double(usual.reduce(0, +)) / Double(usual.count), usual.count))
                            .font(theme.display(.headline))
                            .foregroundStyle(theme.colors.textPrimary)
                    } else {
                        Text("Still learning: \(usual.count) of \(DayStateBoard.minimumDays) days")
                            .font(theme.display(.headline))
                            .foregroundStyle(theme.colors.textPrimary)
                    }
                    Text("App rule: your usual is the average of the \(DayStateBoard.windowDays) days before today, leaving out days marked ill. It needs \(DayStateBoard.minimumDays) days. Grey bars are days marked ill.")
                        .font(theme.body(.caption))
                        .foregroundStyle(theme.colors.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .themedCard()
            }
            .padding(16)
        }
        .background(theme.colors.background.ignoresSafeArea())
        .navigationTitle(scale.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
