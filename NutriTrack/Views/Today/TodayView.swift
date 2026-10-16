import SwiftUI
import CoreData

struct TodayView: View {
    let profile: UserProfile
    let onNavigate: (MainTabView.AppTab) -> Void
    @Environment(\.theme) private var theme
    @Environment(\.managedObjectContext) private var ctx
    @AppStorage("sleepStartTimestamp") private var sleepStartTimestamp: Double = 0
    @State private var isConfirmingSleepReset = false

    @FetchRequest private var todayCheckIn: FetchedResults<DailyCheckIn>
    @FetchRequest private var todayFood: FetchedResults<FoodEntry>
    @FetchRequest private var todaySupLogs: FetchedResults<SupplementLog>
    @FetchRequest private var todayEvaluations: FetchedResults<DailyEvaluation>
    @FetchRequest private var weekPlanned: FetchedResults<PlannedSession>
    @FetchRequest private var weekSessions: FetchedResults<TrainingSession>
    @FetchRequest private var weights: FetchedResults<WeightEntry>

    @State private var confirmClose = false
    @State private var isCheckingIn = false
    @State private var isAskingDayEnergy = false
    @State private var detail: ScoreKind?
    @State private var aerobicLog: TrainingView.AerobicLog?
    @State private var strengthLog: PlannedSession?
    @State private var scrollOffset: CGFloat = 0

    private let weekStart: Date

    private struct NextSession {
        let planned: PlannedSession
        let kind: SessionKind
        let modality: Modality
        let adjusted: AdjustedSession
        let isDone: Bool

        var name: String { kind == .strength ? "Strength" : modality.label }
    }

    init(profile: UserProfile, onNavigate: @escaping (MainTabView.AppTab) -> Void) {
        self.profile = profile
        self.onNavigate = onNavigate
        let start = Calendar.current.startOfDay(for: Date())
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        let week = TargetService.weekStart(for: Date())
        weekStart = week
        let today = NSPredicate(format: "timestamp >= %@ AND timestamp < %@", start as NSDate, end as NSDate)
        _todayCheckIn = FetchRequest(entity: DailyCheckIn.entity(), sortDescriptors: [],
                                     predicate: DailyCheckIn.todayPredicate())
        _todayFood = FetchRequest(entity: FoodEntry.entity(), sortDescriptors: [], predicate: today)
        _todaySupLogs = FetchRequest(entity: SupplementLog.entity(), sortDescriptors: [], predicate: today)
        _todayEvaluations = FetchRequest(entity: DailyEvaluation.entity(), sortDescriptors: [],
                                         predicate: NSPredicate(format: "date >= %@ AND date < %@",
                                                                start as NSDate, end as NSDate))
        _weekPlanned = FetchRequest(entity: PlannedSession.entity(),
                                    sortDescriptors: [NSSortDescriptor(keyPath: \PlannedSession.dayIndex, ascending: true)],
                                    predicate: NSPredicate(format: "weekStart == %@", week as NSDate))
        _weekSessions = FetchRequest(entity: TrainingSession.entity(), sortDescriptors: [],
                                     predicate: NSPredicate(format: "startedAt >= %@ AND startedAt < %@", week as NSDate,
                                                            week.addingTimeInterval(7 * TrainingService.day) as NSDate))
        _weights = FetchRequest(entity: WeightEntry.entity(),
                                sortDescriptors: [NSSortDescriptor(keyPath: \WeightEntry.date, ascending: true)],
                                predicate: NSPredicate(format: "date >= %@",
                                                       start.addingTimeInterval(-TargetService.trendLookbackDays * 86400) as NSDate))
    }

    private var isSleeping: Bool { sleepStartTimestamp > 0 }

    private var bedtime: Date? {
        sleepStartTimestamp > 0 ? Date(timeIntervalSince1970: sleepStartTimestamp) : nil
    }

    private var isDayClosed: Bool { todayEvaluations.first?.closedAt != nil }

    private var todaysPlanned: PlannedSession? {
        let today = Int16(TrainingService.dayIndex(of: Date()))
        let strength = SessionKind.strength.rawValue
        let todays = weekPlanned.filter { $0.dayIndex == today }.sorted { $0.kind != strength && $1.kind == strength }
        let done = Set(weekSessions.compactMap(\.plannedSessionID))
        return todays.first(where: { session in !(session.id.map(done.contains) ?? false) }) ?? todays.first
    }

    private var badDaysThisWeek: Int {
        let endOfToday = Calendar.current.startOfDay(for: Date()).addingTimeInterval(TrainingService.day)
        return TrainingService.badDays(from: weekStart, to: endOfToday, in: ctx)
    }

    private func nextSession(plan: DaySessionPlan?) -> NextSession? {
        guard let planned = todaysPlanned, let plan else { return nil }
        let done = Set(weekSessions.compactMap(\.plannedSessionID))
        return NextSession(planned: planned, kind: SessionKind(rawValue: planned.kind ?? "") ?? .easy,
                           modality: Modality(rawValue: planned.modality ?? "") ?? .walk,
                           adjusted: plan.applied, isDone: planned.id.map(done.contains) ?? false)
    }

    private var weekPath: WeekPath? {
        guard !weekPlanned.isEmpty else { return nil }
        let strength = SessionKind.strength.rawValue
        var plannedByDay = [Double](repeating: 0, count: 7)
        for session in weekPlanned where session.kind != strength {
            let index = Int(session.dayIndex)
            if plannedByDay.indices.contains(index) { plannedByDay[index] += session.targetMinutes }
        }
        var doneByDay = [Double](repeating: 0, count: 7)
        for session in weekSessions where session.kind != strength {
            guard let start = session.startedAt else { continue }
            let index = TrainingService.dayIndex(of: start)
            if doneByDay.indices.contains(index) { doneByDay[index] += session.durationMin }
        }
        return WeekPath.make(plannedByDay: plannedByDay, doneByDay: doneByDay,
                             todayIndex: TrainingService.dayIndex(of: Date()))
    }

    private var weightTrend: (current: Double, change: Double?)? {
        let weighIns = TargetService.classify(Array(weights), in: ctx)
        guard weighIns.count >= 2 else { return nil }
        let rate = WeightTrend.rate(weighIns, now: Date())
        let trend = WeightTrend.ema(weighIns, daytimeOffsetKg: rate.daytimeOffsetKg)
        guard let last = trend.last else { return nil }
        let cutoff = last.date.addingTimeInterval(-28 * 86400)
        let earlier = trend.last { $0.date <= cutoff }
        return (last.weightKg, earlier.map { last.weightKg - $0.weightKg })
    }

    var body: some View {
        NavigationStack {
            let scores = EvaluationService.computeTodayScores(profile: profile, in: ctx)
            let checkIn = todayCheckIn.first
            let color = TrainingService.color(on: Date(), in: ctx)
            let badDays = badDaysThisWeek
            let plan = todaysPlanned.map {
                TrainingService.sessionPlan($0, profile: profile, color: color, badDays: badDays, now: Date(), in: ctx)
            }
            let next = nextSession(plan: plan)
            let path = weekPath
            let tone = checkIn == nil ? theme.colors.textSecondary : color.tint(in: theme)
            let headline = DayHeadline.make(DayHeadline.Input(
                hasCheckIn: checkIn != nil, color: color, sleepHours: checkIn?.sleepHours,
                energy: checkIn.map { Int($0.energyLevel) }, isSick: checkIn?.isSick ?? false,
                hasPain: checkIn?.hasPain ?? false,
                reasons: TrainingService.reasons(on: Date(), in: ctx),
                session: next.map {
                    DayHeadline.Session(name: $0.name, isStrength: $0.kind == .strength,
                                        plannedMinutes: $0.planned.targetMinutes,
                                        adjustedMinutes: $0.adjusted.targetMinutes, isDone: $0.isDone,
                                        hasSuggestion: plan?.suggestion != nil,
                                        isLighter: $0.adjusted.extraRepsInReserve > 0
                                            || $0.adjusted.strengthSets < Int($0.planned.strengthSets))
                }))
            let action = TodayAction.pick(
                hasCheckIn: checkIn != nil,
                hasSessionToLog: next.map { !$0.isDone && !$0.adjusted.isRest } ?? false,
                mealsToday: todayFood.count, isDayClosed: isDayClosed,
                hour: Calendar.current.component(.hour, from: Date()))

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top, spacing: 12) {
                        DayAnswerView(headline: headline, date: Date(), tone: tone)
                        sleepButton
                    }
                    .padding(.top, ScreenBackdrop.headroom(for: theme.style.backdrop))

                    if let birthDate = profile.birthDate, BirthDate.isBirthday(bornOn: birthDate, now: Date()) {
                        Text("Happy birthday\(profile.name.map { ", \($0)" } ?? "").")
                            .font(theme.display(.title3))
                            .foregroundStyle(theme.colors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if isSleeping {
                        TimelineView(.periodic(from: .now, by: 60)) { context in
                            Label {
                                Text(SleepTimerText.caption(startedAt: Date(timeIntervalSince1970: sleepStartTimestamp),
                                                            now: context.date))
                                    .font(theme.body(.caption))
                                    .foregroundStyle(theme.colors.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            } icon: {
                                Image(systemName: "moon.fill")
                                    .font(.caption)
                                    .foregroundStyle(theme.colors.sleep)
                            }
                        }
                    }

                    if checkIn?.hasPain == true {
                        Text("Pain that changes how you move needs rest. If it does not ease in a few days, have it looked at.")
                            .font(theme.body(.caption))
                            .foregroundStyle(theme.colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    HeroScore(readiness: scores.readiness?.value, sleep: scores.sleep?.value, diet: scores.diet?.value,
                              weekPath: path, tone: tone) { detail = $0 }

                    actionCard(action, next: next)
                    if let next, !next.isDone, let checkIn,
                       let text = plan?.suggestionText(kind: next.kind, plannedMinutes: next.planned.targetMinutes,
                                                       plannedSets: Int(next.planned.strengthSets)) {
                        SuggestionCard(text: text) {
                            checkIn.recordSuggestion(.applied, in: ctx)
                        } onKeep: {
                            checkIn.recordSuggestion(.kept, in: ctx)
                        }
                    }
                    if TrainingService.shouldAskLightWeek(weekStart: weekStart, badDays: badDays, in: ctx) {
                        LightWeekCard {
                            TrainingService.setLightWeekChoice(.applied, weekStart: weekStart, in: ctx)
                        } onKeep: {
                            TrainingService.setLightWeekChoice(.kept, weekStart: weekStart, in: ctx)
                        }
                    }
                    tiles(path: path)
                    coachRow
                    if !todayFood.isEmpty && !isDayClosed && action != .closeDay { closeRow }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 110)
            }
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top
            } action: { _, offset in
                scrollOffset = offset
            }
            .background(alignment: .top) {
                ScreenBackdrop(tone: tone)
                    .offset(y: -max(0, scrollOffset))
            }
            .background(theme.colors.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .statusBarScrim(scrollOffset: scrollOffset)
            .task {
                if profile.refreshAge() { try? ctx.save() }
            }
            .navigationDestination(item: $detail) { kind in
                ScoreDetailView(kind: kind, liveScore: liveScore(kind, scores), profile: profile)
            }
            .sheet(isPresented: $isCheckingIn) {
                CheckInSheet(profile: profile, bedtime: bedtime) { answers in
                    let keptBedtime = TimeInBed.validBedtime(bedtime, wakeTime: answers.wakeTime)
                    withAnimation(.easeInOut(duration: 0.3)) {
                        DailyCheckIn.create(answers, bedtime: keptBedtime, in: ctx)
                        sleepStartTimestamp = 0
                    }
                    EvaluationService.ensureTodayEvaluation(profile: profile, in: ctx)
                }
            }
            .sheet(isPresented: $isAskingDayEnergy) {
                DayEnergySheet { level in
                    DailyCheckIn.on(EveningQuestion.day(for: Date()), in: ctx)?.recordDayEnergy(level, in: ctx)
                }
            }
            .sheet(item: $aerobicLog) { log in
                LogAerobicSheet(plannedID: log.plannedID, modality: log.modality, minutes: log.minutes)
            }
            .sheet(item: $strengthLog) { session in
                let applied = TrainingService.sessionPlan(session, profile: profile,
                                                          color: TrainingService.color(on: Date(), in: ctx),
                                                          badDays: badDaysThisWeek, now: Date(), in: ctx).applied
                let reserve = StrengthProgram.targetReserve(
                    weekNumber: TrainingService.week(startingAt: weekStart, in: ctx)
                        .map { TrainingService.weekNumber(of: $0, in: ctx) } ?? 1)
                LogStrengthSheet(
                    plannedID: session.id,
                    exercises: StrengthProgram.exercises(hasGym: TrainingService.profile(in: ctx)?.hasGym ?? false),
                    sets: max(applied.strengthSets, 1),
                    reserve: (reserve.lowerBound + applied.extraRepsInReserve)...(reserve.upperBound + applied.extraRepsInReserve),
                    estimatedMinutes: session.targetMinutes)
            }
            .onAppear { TrainingService.ensureWeek(user: profile, in: ctx) }
            .sensoryFeedback(.success, trigger: todayCheckIn.count)
            .sensoryFeedback(.success, trigger: isDayClosed)
        }
    }

    private func liveScore(_ kind: ScoreKind, _ scores: TodayScores) -> HealthScore? {
        switch kind {
        case .sleep: return scores.sleep
        case .diet: return scores.diet
        case .readiness: return scores.readiness
        }
    }

    private var sleepButton: some View {
        Button {
            if isSleeping {
                isConfirmingSleepReset = true
            } else {
                withAnimation(.easeInOut(duration: 0.2)) {
                    sleepStartTimestamp = Date().timeIntervalSince1970
                }
                let checkIn = DailyCheckIn.on(EveningQuestion.day(for: Date()), in: ctx)
                isAskingDayEnergy = EveningQuestion.shouldAsk(hasCheckIn: checkIn != nil,
                                                             dayEnergy: Int(checkIn?.dayEnergy ?? 0))
            }
        } label: {
            Image(systemName: isSleeping ? "moon.fill" : "moon")
                .font(.title3)
                .accessibilityHidden(true)
                .foregroundStyle(isSleeping ? theme.colors.sleep : theme.colors.textSecondary)
                .frame(width: 44, height: 44)
                .background(theme.colors.surface, in: Circle())
        }
        .buttonStyle(.pressScale)
        .accessibilityLabel("Sleep timer")
        .accessibilityValue(isSleeping ? "On" : "Off")
        .accessibilityHint("Tap when you go to bed. The morning check-in uses it to fill in your hours.")
        .confirmationDialog("Stop the sleep timer?", isPresented: $isConfirmingSleepReset, titleVisibility: .visible) {
            Button("Stop timer", role: .destructive) {
                withAnimation(.easeInOut(duration: 0.2)) { sleepStartTimestamp = 0 }
            }
            Button("Keep it on", role: .cancel) {}
        } message: {
            Text("The time you went to bed will be lost. To save your sleep, do the morning check-in instead; it switches the timer off.")
        }
    }

    @ViewBuilder
    private func actionCard(_ action: TodayAction?, next: NextSession?) -> some View {
        switch action {
        case .checkIn:
            ActionCard(eyebrow: "Start here", title: "Morning check-in",
                       detail: "Thirty seconds: sleep, energy, anything off.", buttonTitle: "Check in") {
                isCheckingIn = true
            }
        case .session:
            if let next {
                ActionCard(eyebrow: "Today's session", title: sessionTitle(next), detail: sessionDetail(next),
                           note: next.adjusted.note, buttonTitle: "Log session") {
                    startLog(next)
                }
            }
        case .closeDay:
            ActionCard(eyebrow: "Evening", title: "Close the day",
                       detail: "It locks today's diet score and asks the coach for a review.",
                       buttonTitle: "Close day") {
                confirmClose = true
            }
            .closeDayDialog(isPresented: $confirmClose, onConfirm: closeToday)
        case .dayClosed:
            ActionCard(eyebrow: "Day closed", title: "Diet \(todayEvaluations.first?.dietScore ?? 0)",
                       detail: "The day is locked. You can still fix meals; the score is recalculated.",
                       buttonTitle: "Read the review") {
                detail = .diet
            }
        case nil:
            EmptyView()
        }
    }

    private func sessionTitle(_ next: NextSession) -> String {
        if next.kind == .strength {
            let sets = next.adjusted.strengthSets
            return "Strength · \(sets) set\(sets == 1 ? "" : "s")"
        }
        return "\(next.modality.label) · \(Int(next.adjusted.targetMinutes.rounded())) min"
    }

    private func sessionDetail(_ next: NextSession) -> String {
        next.kind == .strength
            ? "Controlled reps, stopping with a few in reserve."
            : "Easy: you should be able to talk in full sentences."
    }

    private func startLog(_ next: NextSession) {
        if next.kind == .strength {
            strengthLog = next.planned
        } else {
            aerobicLog = TrainingView.AerobicLog(plannedID: next.planned.id, modality: next.modality,
                                                 minutes: next.adjusted.targetMinutes)
        }
    }

    private enum Tile: Hashable {
        case eaten
        case protein
        case week
        case weight
    }

    private func tiles(path: WeekPath?) -> some View {
        let trend = weightTrend
        var kinds: [Tile] = [.eaten, .protein]
        if let path, path.totalPlanned > 0 { kinds.append(.week) }
        if trend != nil { kinds.append(.weight) }
        let rows = stride(from: 0, to: kinds.count, by: 2).map { Array(kinds[$0..<min($0 + 2, kinds.count)]) }
        let targets = profile.macroTargets
        let eaten = NutritionAnalysis.sum(todayFood.map(\.analysis))
        return Grid(horizontalSpacing: 10, verticalSpacing: 10) {
            ForEach(rows, id: \.self) { row in
                GridRow {
                    ForEach(row, id: \.self) { kind in
                        tile(kind, eaten: eaten, targets: targets, path: path, trend: trend)
                    }
                    if row.count == 1 {
                        Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func tile(_ kind: Tile, eaten: NutritionAnalysis, targets: MacroTargets, path: WeekPath?,
                      trend: (current: Double, change: Double?)?) -> some View {
        switch kind {
        case .eaten:
            tileButton(.nutrition) {
                MetricTile(label: "Eaten", value: "\(Int(eaten.calories.rounded()))",
                           unit: "/ \(Int(targets.calories.rounded())) kcal",
                           bar: .make(value: eaten.calories, target: targets.calories), color: theme.colors.diet)
            }
        case .protein:
            tileButton(.nutrition) {
                MetricTile(label: "Protein", value: "\(Int(eaten.proteinG.rounded()))",
                           unit: "/ \(Int(targets.proteinG.rounded())) g",
                           bar: .make(value: eaten.proteinG, target: targets.proteinG), color: theme.colors.protein)
            }
        case .week:
            tileButton(.training) {
                MetricTile(label: "This week", value: "\(Int((path?.doneSoFar ?? 0).rounded()))",
                           unit: "/ \(Int((path?.totalPlanned ?? 0).rounded())) min",
                           bar: .make(value: path?.doneSoFar ?? 0, target: path?.totalPlanned),
                           color: theme.colors.readiness)
            }
        case .weight:
            tileButton(.trends) {
                MetricTile(label: "Weight trend", value: String(format: "%.1f", trend?.current ?? 0), unit: "kg",
                           caption: trend?.change.map { String(format: "%+.1f kg in 4 weeks", $0) })
            }
        }
    }

    private func tileButton<Label: View>(_ tab: MainTabView.AppTab, @ViewBuilder label: () -> Label) -> some View {
        Button { onNavigate(tab) } label: { label() }
            .buttonStyle(.pressScale)
    }

    private var closeRow: some View {
        Button { confirmClose = true } label: {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.seal")
                    .accessibilityHidden(true)
                Text("Close the day")
                Spacer()
            }
            .font(theme.body(.subheadline))
            .foregroundStyle(theme.colors.textSecondary)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressScale)
        .closeDayDialog(isPresented: $confirmClose, onConfirm: closeToday)
    }

    private func closeToday() {
        let today = Date()
        guard EvaluationService.closeDay(today, profile: profile, isLogComplete: true, in: ctx) else { return }
        EvaluationService.requestDietCommentary(day: today, profile: profile, in: ctx)
    }

    private var coachRow: some View {
        NavigationLink(destination: DailyCoachView(profile: profile)) {
            HStack(spacing: 12) {
                Image(systemName: "brain.head.profile")
                    .foregroundStyle(theme.colors.coach)
                    .accessibilityHidden(true)
                Text("Full day analysis")
                    .font(theme.body(.subheadline).weight(.medium))
                    .foregroundStyle(theme.colors.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.colors.textMuted)
                    .accessibilityHidden(true)
            }
            .themedCard()
        }
        .buttonStyle(.pressScale)
    }
}

private extension View {
    func closeDayDialog(isPresented: Binding<Bool>, onConfirm: @escaping () -> Void) -> some View {
        confirmationDialog("Close today?", isPresented: isPresented, titleVisibility: .visible) {
            Button("Close the day", action: onConfirm)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You can still fix or add meals afterwards; the score is recalculated.")
        }
    }
}
