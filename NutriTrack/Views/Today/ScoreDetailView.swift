import SwiftUI
import CoreData
import Charts

enum ScoreKind: String {
    case sleep = "Sleep"
    case diet = "Diet"
    case readiness = "Readiness"

    func color(in theme: Theme) -> Color {
        switch self {
        case .sleep: return theme.colors.sleep
        case .diet: return theme.colors.diet
        case .readiness: return theme.colors.readiness
        }
    }

    var icon: String {
        switch self {
        case .sleep: return "moon.stars.fill"
        case .diet: return "fork.knife"
        case .readiness: return "bolt.heart.fill"
        }
    }
}

struct ScoreDetailView: View {
    let kind: ScoreKind
    let liveScore: HealthScore?
    let profile: UserProfile
    @Environment(\.theme) private var theme
    @Environment(\.managedObjectContext) private var ctx
    @ObservedObject private var jobStore = ModelJobStore.shared

    private var isGenerating: Bool {
        let today = Calendar.current.startOfDay(for: Date())
        return jobStore.isPending(kind == .diet ? .dietEvaluation(day: today) : .scoreEvaluation(day: today))
    }

    @FetchRequest private var history: FetchedResults<DailyEvaluation>
    @FetchRequest private var todayEvaluations: FetchedResults<DailyEvaluation>
    @FetchRequest private var yesterdayEvaluations: FetchedResults<DailyEvaluation>

    init(kind: ScoreKind, liveScore: HealthScore?, profile: UserProfile) {
        self.kind = kind
        self.liveScore = liveScore
        self.profile = profile
        let start = Calendar.current.date(byAdding: .day, value: -14,
                                          to: Calendar.current.startOfDay(for: Date()))!
        _history = FetchRequest(entity: DailyEvaluation.entity(),
                                sortDescriptors: [NSSortDescriptor(keyPath: \DailyEvaluation.date, ascending: true)],
                                predicate: kind == .diet ? EvaluationService.dietHistoryPredicate(since: start)
                                                         : EvaluationService.historyPredicate(since: start))
        let todayStart = Calendar.current.startOfDay(for: Date())
        let todayEnd = Calendar.current.date(byAdding: .day, value: 1, to: todayStart)!
        let yesterdayStart = Calendar.current.date(byAdding: .day, value: -1, to: todayStart)!
        _todayEvaluations = FetchRequest(entity: DailyEvaluation.entity(), sortDescriptors: [],
                                         predicate: NSPredicate(format: "date >= %@ AND date < %@",
                                                                todayStart as NSDate, todayEnd as NSDate))
        _yesterdayEvaluations = FetchRequest(entity: DailyEvaluation.entity(), sortDescriptors: [],
                                             predicate: NSPredicate(format: "date >= %@ AND date < %@",
                                                                    yesterdayStart as NSDate, todayStart as NSDate))
    }

    private func score(of evaluation: DailyEvaluation) -> Int {
        switch kind {
        case .sleep: return Int(evaluation.sleepScore)
        case .diet: return Int(evaluation.dietScore)
        case .readiness: return Int(evaluation.readinessScore)
        }
    }

    private var aiText: String? {
        guard let today = todayEvaluations.first else { return nil }
        switch kind {
        case .sleep: return today.sleepText
        case .diet: return today.dietText
        case .readiness: return today.readinessText
        }
    }

    private var isDayClosed: Bool { todayEvaluations.first?.closedAt != nil }

    private var yesterdayReview: String? {
        guard kind == .diet, let text = yesterdayEvaluations.first?.dietText, !text.isEmpty else { return nil }
        return text
    }

    private func coachText(_ text: String) -> some View {
        Text((try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(text))
            .font(theme.body(.subheadline))
            .environment(\.openURL, OpenURLAction { _ in .discarded })
            .foregroundStyle(theme.colors.textPrimary)
            .lineSpacing(4)
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                ScoreRingView(label: kind.rawValue, score: liveScore?.value,
                              color: kind.color(in: theme), icon: kind.icon, size: 116,
                              placeholder: kind == .diet && liveScore == nil ? "—" : nil)
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
                    .themedCard()

                if let components = liveScore?.components {
                    VStack(alignment: .leading, spacing: 12) {
                        EyebrowText("Breakdown")
                        ForEach(components, id: \.self) { component in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(component.label)
                                        .font(theme.body(.subheadline))
                                        .foregroundStyle(theme.colors.textPrimary)
                                    Spacer()
                                    Text("\(Int((component.score * 100).rounded()))%")
                                        .font(theme.number(.subheadline))
                                        .foregroundStyle(theme.colors.textPrimary)
                                    Text("· weight \(Int((component.weight * 100).rounded()))%")
                                        .font(theme.body(.caption))
                                        .foregroundStyle(theme.colors.textMuted)
                                }
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(theme.colors.textMuted.opacity(0.2))
                                            .frame(height: 6)
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(kind.color(in: theme))
                                            .frame(width: geo.size.width * component.score, height: 6)
                                    }
                                }
                                .frame(height: 6)
                            }
                        }
                    }
                    .themedCard()
                } else {
                    Text(kind == .diet ? "Log a meal to see your diet score." : "Complete your morning check-in to unlock this score.")
                        .font(theme.body(.subheadline))
                        .foregroundStyle(theme.colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .themedCard()
                }

                if history.count >= 2 {
                    VStack(alignment: .leading, spacing: 10) {
                        EyebrowText("Last 14 days")
                        Chart(history) { evaluation in
                            LineMark(x: .value("Day", evaluation.date ?? Date()),
                                     y: .value("Score", score(of: evaluation)))
                                .interpolationMethod(.catmullRom)
                                .foregroundStyle(kind.color(in: theme))
                            PointMark(x: .value("Day", evaluation.date ?? Date()),
                                      y: .value("Score", score(of: evaluation)))
                                .foregroundStyle(kind.color(in: theme))
                                .symbolSize(28)
                        }
                        .chartYScale(domain: 0...100)
                        .frame(height: 170)
                    }
                    .themedCard()
                }

                VStack(alignment: .leading, spacing: 10) {
                    EyebrowText("Coach's take")
                    if let aiText, !aiText.isEmpty {
                        coachText(aiText)
                    } else if isGenerating {
                        HStack(spacing: 10) {
                            ProgressView()
                                .tint(theme.colors.coach)
                            Text("Analysing...")
                                .font(theme.body(.subheadline))
                                .foregroundStyle(theme.colors.textSecondary)
                        }
                    } else if kind == .diet && !isDayClosed {
                        Text("Available after you close the day.")
                            .font(theme.body(.subheadline))
                            .foregroundStyle(theme.colors.textSecondary)
                    } else if liveScore == nil {
                        Text("Available after your morning check-in.")
                            .font(theme.body(.subheadline))
                            .foregroundStyle(theme.colors.textSecondary)
                    } else {
                        Button {
                            generate(force: false)
                        } label: {
                            Label("Generate analysis", systemImage: "sparkles")
                        }
                        .buttonStyle(.themedPrimary(fill: theme.colors.coach))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .themedCard()

                if let yesterdayReview {
                    VStack(alignment: .leading, spacing: 10) {
                        EyebrowText("Yesterday's review")
                        coachText(yesterdayReview)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .themedCard()
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(theme.colors.background.ignoresSafeArea())
        .navigationTitle(kind.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if aiText == nil, liveScore != nil, kind != .diet {
                generate(force: false)
            }
        }
    }

    private func generate(force: Bool) {
        guard !isGenerating else { return }
        if kind == .diet {
            EvaluationService.requestDietCommentary(day: Date(), profile: profile, in: ctx)
        } else {
            EvaluationService.ensureTodayEvaluation(profile: profile, in: ctx, force: force)
        }
    }
}
