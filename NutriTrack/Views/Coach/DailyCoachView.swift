import SwiftUI
import CoreData

struct DailyCoachView: View {
    @Environment(\.theme) private var theme
    let profile: UserProfile
    @Environment(\.managedObjectContext) private var ctx

    @FetchRequest private var todayFood: FetchedResults<FoodEntry>
    @FetchRequest private var todaySupLogs: FetchedResults<SupplementLog>
    @FetchRequest private var templates: FetchedResults<SupplementTemplate>
    @FetchRequest private var recentCheckIns: FetchedResults<DailyCheckIn>

    @FetchRequest private var todayEvaluations: FetchedResults<DailyEvaluation>
    @ObservedObject private var jobStore = ModelJobStore.shared

    private var coachKind: ModelJobKind { .dailyCoach(day: Calendar.current.startOfDay(for: Date())) }
    private var coachText: String? { todayEvaluations.first?.coachText }
    private var isLoading: Bool { jobStore.isPending(coachKind) }
    private var errorMessage: String? { jobStore.failures[coachKind] }

    init(profile: UserProfile) {
        self.profile = profile
        let start = Calendar.current.startOfDay(for: Date())
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        let pred = NSPredicate(format: "timestamp >= %@ AND timestamp < %@", start as NSDate, end as NSDate)
        _todayFood = FetchRequest(entity: FoodEntry.entity(), sortDescriptors: [], predicate: pred)
        _todaySupLogs = FetchRequest(entity: SupplementLog.entity(), sortDescriptors: [], predicate: pred)
        _templates = FetchRequest(entity: SupplementTemplate.entity(), sortDescriptors: [])
        _recentCheckIns = FetchRequest(entity: DailyCheckIn.entity(),
                                       sortDescriptors: [NSSortDescriptor(keyPath: \DailyCheckIn.date, ascending: false)],
                                       predicate: DailyCheckIn.lastDaysPredicate(7))
        _todayEvaluations = FetchRequest(entity: DailyEvaluation.entity(), sortDescriptors: [],
                                         predicate: NSPredicate(format: "date >= %@ AND date < %@",
                                                                start as NSDate, end as NSDate))
    }

    private var checkInSummary: String? {
        guard !recentCheckIns.isEmpty else { return nil }
        var lines: [String] = []
        if let today = recentCheckIns.first(where: { Calendar.current.isDateInToday($0.date ?? .distantPast) }) {
            lines.append("- Today: energy \(today.energyLevel)/5, slept \(String(format: "%.1f", today.sleepHours))h, sleep quality \(today.sleepQuality)/5")
        }
        if recentCheckIns.count >= 2 {
            let avgEnergy = recentCheckIns.reduce(0.0) { $0 + Double($1.energyLevel) } / Double(recentCheckIns.count)
            let avgSleep = recentCheckIns.reduce(0.0) { $0 + $1.sleepHours } / Double(recentCheckIns.count)
            lines.append("- Last \(recentCheckIns.count) days: avg energy \(String(format: "%.1f", avgEnergy))/5, avg sleep \(String(format: "%.1f", avgSleep))h")
        }
        return lines.isEmpty ? nil : lines.joined(separator: "\n        ")
    }

    private var dailySummary: DailySummary {
        let supNutrients = todaySupLogs.compactMap { log -> NutritionAnalysis? in
            if let snapshot = log.snapshotNutrients { return snapshot }
            guard let t = templates.first(where: { $0.id?.uuidString == log.templateID }) else { return nil }
            return t.nutrientsScaled(by: log.doses)
        }
        let supNames = todaySupLogs.compactMap { log in
            log.name ?? templates.first(where: { $0.id?.uuidString == log.templateID })?.name
        }.joined(separator: ", ")

        return DailySummary(
            calories: todayFood.reduce(0) { $0 + $1.calories } + supNutrients.reduce(0) { $0 + $1.calories },
            proteinG: todayFood.reduce(0) { $0 + $1.proteinG } + supNutrients.reduce(0) { $0 + $1.proteinG },
            carbsG: todayFood.reduce(0) { $0 + $1.carbsG } + supNutrients.reduce(0) { $0 + $1.carbsG },
            fatG: todayFood.reduce(0) { $0 + $1.fatG } + supNutrients.reduce(0) { $0 + $1.fatG },
            fiberG: todayFood.reduce(0) { $0 + $1.fiberG },
            omega3G: todayFood.reduce(0) { $0 + $1.omega3G } + supNutrients.reduce(0) { $0 + $1.omega3G },
            ironMg: todayFood.reduce(0) { $0 + $1.ironMg } + supNutrients.reduce(0) { $0 + $1.ironMg },
            zincMg: todayFood.reduce(0) { $0 + $1.zincMg } + supNutrients.reduce(0) { $0 + $1.zincMg },
            magnesiumMg: todayFood.reduce(0) { $0 + $1.magnesiumMg } + supNutrients.reduce(0) { $0 + $1.magnesiumMg },
            vitaminDUg: todayFood.reduce(0) { $0 + $1.vitaminDUg } + supNutrients.reduce(0) { $0 + $1.vitaminDUg },
            calciumMg: todayFood.reduce(0) { $0 + $1.calciumMg } + supNutrients.reduce(0) { $0 + $1.calciumMg },
            supplementsDescription: supNames.isEmpty ? "none" : supNames
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(theme.colors.coach.opacity(0.15))
                        .frame(width: 88, height: 88)
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 38))
                        .foregroundStyle(theme.colors.coach)
                }
                .padding(.top, 24)
                .accessibilityHidden(true)

                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(theme.colors.coach)
                        Text("Analysing your day...")
                            .font(theme.body(.subheadline))
                            .foregroundStyle(theme.colors.textSecondary)
                    }
                    .padding(.top, 20)
                    .transition(.opacity)
                } else if let text = coachText {
                    Text((try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(text))
                        .font(theme.body(.body))
                        .environment(\.openURL, OpenURLAction { _ in .discarded })
                        .foregroundStyle(theme.colors.textPrimary)
                        .lineSpacing(5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .themedCard(padding: 20)
                        .padding(.horizontal, 16)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else if let error = errorMessage {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(theme.colors.warning)
                        Text(error)
                            .font(theme.body(.subheadline))
                            .foregroundStyle(theme.colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    Text("Get personalised recommendations based on what you've eaten today.")
                        .font(theme.body(.subheadline))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(theme.colors.textSecondary)
                        .padding(.horizontal, 40)
                }

                if !isLoading {
                    Button {
                        loadCoach()
                    } label: {
                        Label(coachText == nil ? "Analyse my day" : "Refresh analysis",
                              systemImage: "sparkles")
                    }
                    .buttonStyle(.themedPrimary(fill: theme.colors.coach))
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 24)
            .animation(.easeInOut(duration: 0.3), value: isLoading)
        }
        .background(theme.colors.background.ignoresSafeArea())
        .navigationTitle("Daily Coach")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func loadCoach() {
        do {
            let body = try GeminiService.coachRequestBody(summary: dailySummary,
                                                          profile: profile.userProfileData,
                                                          checkInSummary: checkInSummary)
            try BackgroundModelClient.shared.enqueue(coachKind, body: body)
        } catch {
            jobStore.recordFailure(error.localizedDescription, for: coachKind)
        }
    }
}
