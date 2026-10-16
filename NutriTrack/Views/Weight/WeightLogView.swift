import SwiftUI
import CoreData
import Charts

struct WeightLogView: View {
    @Environment(\.theme) private var theme
    @ObservedObject var profile: UserProfile
    @Environment(\.managedObjectContext) private var ctx
    @FetchRequest(entity: WeightEntry.entity(),
                  sortDescriptors: [NSSortDescriptor(keyPath: \WeightEntry.date, ascending: true)])
    private var entries: FetchedResults<WeightEntry>

    @State private var pickedWeight: Double?
    @State private var showInput = false
    @State private var pendingDelete: WeightEntry?
    @State private var showRangeError = false
    @State private var pendingWeight: (weightKg: Double, percent: Double)?

    var body: some View {
        let weighIns = TargetService.classify(Array(entries), in: ctx)
        let rate = WeightTrend.rate(weighIns, now: Date())
        let trend = WeightTrend.ema(weighIns, daytimeOffsetKg: rate.daytimeOffsetKg)
        let contexts = Dictionary(weighIns.map { ($0.date, $0.context) }, uniquingKeysWith: { first, _ in first })
        ScrollView {
            LazyVStack(spacing: 14) {
                HStack(spacing: 10) {
                    StatCard(label: "Trend",
                             value: String(format: "%.1f kg", trend.last?.weightKg ?? profile.weightKg))
                    StatCard(label: "Pace",
                             value: rate.isValid ? String(format: "%+.2f kg/wk", rate.kgPerWeek) : "—")
                }
                if !rate.isValid && !entries.isEmpty {
                    Text("Pace needs 8 weigh-ins in the last 4 weeks, 3 of them in the first 10 days and 3 in the last 10.")
                        .font(theme.body(.caption))
                        .foregroundStyle(theme.colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if let offset = rate.daytimeOffsetKg {
                    Text(String(format: "Daytime weigh-ins run %+.1f kg against fasted ones. That difference is removed from the trend and the pace.", offset))
                        .font(theme.body(.caption))
                        .foregroundStyle(theme.colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if entries.count >= 2 {
                    VStack(alignment: .leading, spacing: 10) {
                        EyebrowText("Progress")
                        Chart {
                            ForEach(entries) { e in
                            AreaMark(x: .value("Date", e.date ?? Date()), y: .value("kg", e.weightKg))
                                .interpolationMethod(.catmullRom)
                                .foregroundStyle(
                                    LinearGradient(colors: [theme.colors.accent.opacity(0.25),
                                                            theme.colors.accent.opacity(0.02)],
                                                   startPoint: .top, endPoint: .bottom)
                                )
                            LineMark(x: .value("Date", e.date ?? Date()), y: .value("kg", e.weightKg),
                                     series: .value("Series", "Weigh-ins"))
                                .interpolationMethod(.catmullRom)
                                .foregroundStyle(theme.colors.accent)
                                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                            PointMark(x: .value("Date", e.date ?? Date()), y: .value("kg", e.weightKg))
                                .foregroundStyle(theme.colors.accent)
                                .symbolSize(30)
                            }
                            ForEach(trend, id: \.date) { point in
                                LineMark(x: .value("Date", point.date), y: .value("kg", point.weightKg),
                                         series: .value("Series", "Trend"))
                                    .interpolationMethod(.catmullRom)
                                    .foregroundStyle(theme.colors.textSecondary)
                                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 3]))
                            }
                        }
                        .chartYScale(domain: .automatic(includesZero: false))
                        .frame(height: 200)
                    }
                    .themedCard()
                }

                if entries.isEmpty {
                    EmptyStateCard(
                        icon: "scalemass",
                        title: "No weigh-ins yet",
                        message: "Log your weight to see the trend.",
                        actionTitle: "Log weight",
                        action: { showInput = true }
                    )
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            EyebrowText("Log")
                            Spacer()
                            Button { showInput = true } label: {
                                Image(systemName: "plus")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(theme.colors.onAccent)
                                    .frame(width: 28, height: 28)
                                    .background(theme.colors.accent, in: Circle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Log weight")
                        }
                        ForEach(entries.reversed()) { e in
                            HStack {
                                Image(systemName: "scalemass.fill")
                                    .foregroundStyle(theme.colors.accent)
                                    .font(.caption)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(e.date ?? Date(), style: .date)
                                        .font(theme.body(.subheadline))
                                        .foregroundStyle(theme.colors.textPrimary)
                                    if let context = e.date.flatMap({ contexts[$0] }) {
                                        Text(contextLabel(context))
                                            .font(theme.body(.caption))
                                            .foregroundStyle(theme.colors.textSecondary)
                                    }
                                }
                                Spacer()
                                Text(String(format: "%.1f kg", e.weightKg))
                                    .font(theme.number(.subheadline))
                                    .foregroundStyle(theme.colors.textPrimary)
                                Button {
                                    pendingDelete = e
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.caption)
                                        .foregroundStyle(theme.colors.danger)
                                        .frame(width: 44, height: 44)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Delete weigh-in")
                            }
                        }
                    }
                    .themedCard()
                }
            }
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .alert("Delete this weigh-in?",
               isPresented: Binding(get: { pendingDelete != nil },
                                    set: { if !$0 { pendingDelete = nil } })) {
            Button("Delete", role: .destructive) {
                if let e = pendingDelete { ctx.delete(e); try? ctx.save() }
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        }
        .sheet(isPresented: $showInput, onDismiss: submit) {
            NumberWheelSheet(title: "Log weight", value: entries.last?.weightKg ?? profile.weightKg,
                             range: Int(WeightValidator.range.lowerBound)...Int(WeightValidator.range.upperBound),
                             hasTenths: true, unit: "kg", confirmTitle: "Save") { pickedWeight = $0 }
        }
        .alert("Weight not saved", isPresented: $showRangeError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(WeightValidator.rangeMessage)
        }
        .alert("Check this weight",
               isPresented: Binding(get: { pendingWeight != nil },
                                    set: { if !$0 { pendingWeight = nil } })) {
            Button("Save anyway") {
                if let pending = pendingWeight { save(pending.weightKg) }
                pendingWeight = nil
            }
            Button("Cancel", role: .cancel) { pendingWeight = nil }
        } message: {
            Text(pendingWeight.map { WeightValidator.confirmationMessage(weightKg: $0.weightKg, percent: $0.percent) } ?? "")
        }
    }

    private func submit() {
        guard let weight = pickedWeight else { return }
        pickedWeight = nil
        switch WeightValidator.check(weight, last: entries.last?.weightKg) {
        case .invalid: showRangeError = true
        case .needsConfirmation(let percent): pendingWeight = (weight, percent)
        case .ok: save(weight)
        }
    }

    private func save(_ weight: Double) {
        WeightEntry.log(weightKg: weight, in: ctx)
        profile.weightKg = weight
        try? ctx.save()
    }

    private func contextLabel(_ context: WeighInContext) -> String {
        switch context {
        case .fasted: return "Fasted"
        case .daytime: return "During the day"
        case .afterTraining: return "After training · not used for the pace"
        }
    }
}
